use anyhow::{Context, Result};
use log::{error, info, warn};
use serde::{Deserialize, Serialize};
use std::fs;
use std::io::{BufRead, BufReader, Write};
use std::os::unix::fs::PermissionsExt;
use std::path::Path;
use std::process::Command;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

const SOCKET_PATH: &str = "/run/asnux/asnux-daemon.sock";
const SYSFS_BASE: &str = "/sys/module/asnux/parameters";

#[derive(Debug, Serialize, Deserialize)]
struct Config {
    buffer_size: u32,
    sample_rate: u32,
    channels: u32,
    periods: u32,
    default_engine: bool,
    #[serde(default = "default_realtime_priority")]
    realtime_priority: i32,
}

fn default_realtime_priority() -> i32 { 80 }

impl Default for Config {
    fn default() -> Self {
        Self {
            buffer_size: 256,
            sample_rate: 48000,
            channels: 2,
            periods: 4,
            default_engine: false,
            realtime_priority: 80,
        }
    }
}

#[derive(Debug, Serialize, Deserialize)]
struct Request {
    method: String,
    params: serde_json::Value,
}

#[derive(Debug, Serialize, Deserialize)]
struct Response {
    status: String,
    data: serde_json::Value,
    error: Option<String>,
}

fn read_sysfs_param(name: &str) -> Result<String> {
    let path = format!("{}/{}", SYSFS_BASE, name);
    fs::read_to_string(&path)
        .map(|s| s.trim().to_string())
        .with_context(|| format!("Failed to read {}", path))
}

fn write_sysfs_param(name: &str, value: &str) -> Result<()> {
    let path = format!("{}/{}", SYSFS_BASE, name);
    fs::write(&path, value)
        .with_context(|| format!("Failed to write {} to {}", value, path))
}

fn is_module_loaded() -> bool {
    Path::new(SYSFS_BASE).exists()
}

fn load_module(config: &Config) -> Result<()> {
    info!("Loading ASNUX module...");

    let output = Command::new("modprobe")
        .arg("asnux")
        .arg(format!("buffer_size={}", config.buffer_size))
        .arg(format!("sample_rate={}", config.sample_rate))
        .arg(format!("channels={}", config.channels))
        .arg(format!("periods={}", config.periods))
        .output()
        .context("Failed to execute modprobe")?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        error!("modprobe asnux failed: {}", stderr);

        warn!("Attempting manual module insertion...");
        let kernel_release = Command::new("uname")
            .arg("-r")
            .output()
            .context("Failed to get kernel release")?
            .stdout;
        let kernel_release = String::from_utf8_lossy(&kernel_release)
            .trim()
            .to_string();

        let candidate_paths = vec![
            format!("/lib/modules/{}/extra/asnux.ko", kernel_release),
            format!("/lib/modules/{}/misc/asnux.ko", kernel_release),
            "/usr/local/lib/modules/asnux.ko".to_string(),
        ];

        let mut loaded = false;
        for module_path in &candidate_paths {
            if !Path::new(module_path).exists() {
                continue;
            }
            let output = Command::new("insmod")
                .arg(module_path)
                .output()
                .context("Failed to execute insmod")?;
            if output.status.success() {
                loaded = true;
                break;
            }
        }
        if !loaded {
            anyhow::bail!("Cannot load ASNUX module: module not found in any path");
        }
    }

    info!("ASNUX module loaded successfully");
    Ok(())
}

fn unload_module() -> Result<()> {
    info!("Unloading ASNUX module...");
    let output = Command::new("modprobe")
        .arg("-r")
        .arg("asnux")
        .output()
        .context("Failed to execute modprobe -r")?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        anyhow::bail!("Cannot unload module: {}", stderr);
    }
    info!("ASNUX module unloaded");
    Ok(())
}

fn get_asnux_card_num() -> Result<u32> {
    let content = fs::read_to_string("/proc/asound/cards")
        .context("Failed to read /proc/asound/cards")?;

    for line in content.lines() {
        let lower = line.to_lowercase();
        if lower.contains("asnux") {
            let num = line
                .split_whitespace()
                .next()
                .and_then(|s| s.parse::<u32>().ok())
                .context("Failed to parse card number")?;
            return Ok(num);
        }
    }
    anyhow::bail!("ASNUX card not found in /proc/asound/cards")
}

fn list_cards() -> Result<serde_json::Value> {
    let content = fs::read_to_string("/proc/asound/cards")
        .context("Failed to read /proc/asound/cards")?;

    let mut cards = Vec::new();
    let lines: Vec<&str> = content.lines().collect();
    let mut i = 0;
    while i < lines.len() {
        let line = lines[i].trim();
        if line.is_empty() || !line.chars().next().map(|c| c.is_ascii_digit()).unwrap_or(false) {
            i += 1;
            continue;
        }
        let num: u32 = match line.split_whitespace().next().and_then(|s| s.parse().ok()) {
            Some(n) => n,
            None => { i += 1; continue; }
        };
        let bracket_start = line.find('[').unwrap_or(0);
        let bracket_end = line.find(']').unwrap_or(0);
        let short_name = if bracket_start > 0 && bracket_end > bracket_start {
            line[bracket_start+1..bracket_end].trim().to_string()
        } else {
            "Unknown".to_string()
        };
        let desc = if bracket_end > 0 && line.len() > bracket_end + 2 {
            line[bracket_end+2..].trim().to_string()
        } else {
            String::new()
        };

        let max_channels = get_card_max_channels(num).unwrap_or(2);

        cards.push(serde_json::json!({
            "index": num,
            "name": short_name,
            "description": desc,
            "max_channels": max_channels,
        }));
        i += 1;
    }
    Ok(serde_json::json!(cards))
}

fn get_card_max_channels(card: u32) -> Result<u32> {
    let output = Command::new("amixer")
        .arg("-c").arg(card.to_string())
        .arg("scontrols")
        .output()
        .ok();
    let is_asnux = output.map(|o| {
        String::from_utf8_lossy(&o.stdout).contains("ASNUX")
    }).unwrap_or(false);

    Ok(if is_asnux { 8 } else { 2 })
}

fn apply_config_alsa(config: &Config, card: u32) -> Result<()> {
    info!("Applying config live via ALSA mixer on card {}: buffer={}, rate={}",
          card, config.buffer_size, config.sample_rate);

    let buffer_output = Command::new("amixer")
        .arg("-c").arg(card.to_string())
        .arg("sset").arg("ASNUX Buffer Size")
        .arg(config.buffer_size.to_string())
        .output()
        .context("Failed to run amixer for Buffer Size")?;

    if !buffer_output.status.success() {
        let stderr = String::from_utf8_lossy(&buffer_output.stderr);
        warn!("amixer buffer_size warning: {}", stderr);
    }

    let rate_output = Command::new("amixer")
        .arg("-c").arg(card.to_string())
        .arg("sset").arg("ASNUX Sample Rate")
        .arg(config.sample_rate.to_string())
        .output()
        .context("Failed to run amixer for Sample Rate")?;

    if !rate_output.status.success() {
        let stderr = String::from_utf8_lossy(&rate_output.stderr);
        warn!("amixer sample_rate warning: {}", stderr);
    }

    info!("Config applied live via ALSA mixer");
    Ok(())
}

fn apply_config(config: &Config) -> Result<()> {
    if !is_module_loaded() {
        anyhow::bail!("ASNUX module not loaded");
    }

    info!("Applying config: buffer={}, rate={}, channels={}, periods={}",
          config.buffer_size, config.sample_rate, config.channels, config.periods);

    write_sysfs_param("buffer_size", &config.buffer_size.to_string())?;
    write_sysfs_param("sample_rate", &config.sample_rate.to_string())?;
    write_sysfs_param("channels", &config.channels.to_string())?;
    write_sysfs_param("periods", &config.periods.to_string())?;

    info!("Config written to sysfs (for persistence on next reload)");

    let card = get_asnux_card_num()?;
    apply_config_alsa(config, card)?;

    Ok(())
}

fn get_alsa_value(card: u32, control: &str) -> Result<String> {
    let output = Command::new("amixer")
        .arg("-c").arg(card.to_string())
        .arg("sget").arg(control)
        .output()
        .context("Failed to run amixer")?;

    let stdout = String::from_utf8_lossy(&output.stdout);
    for line in stdout.lines() {
        if let Some(val) = line.split("Item0:").nth(1) {
            return Ok(val.trim().trim_matches('\'').to_string());
        }
    }
    for line in stdout.lines() {
        if line.trim().starts_with("Mono:") {
            let val = line.split("Mono:").nth(1).unwrap_or("0");
            return Ok(val.split_whitespace().next().unwrap_or("0").to_string());
        }
    }
    for line in stdout.lines() {
        if line.trim().starts_with("Front Left:") {
            let val = line.split("Front Left:").nth(1).unwrap_or("0");
            return Ok(val.split_whitespace().next().unwrap_or("0").to_string());
        }
    }
    anyhow::bail!("Cannot parse amixer output for {}", control)
}

fn get_status() -> Result<serde_json::Value> {
    let loaded = is_module_loaded();
    let mut status = serde_json::json!({
        "module_loaded": loaded,
    });

    if loaded {
        let buf = read_sysfs_param("buffer_size").unwrap_or_default().trim().parse::<u32>().unwrap_or(0);
        let rate = read_sysfs_param("sample_rate").unwrap_or_default().trim().parse::<u32>().unwrap_or(0);
        let ch = read_sysfs_param("channels").unwrap_or_default().trim().parse::<u32>().unwrap_or(0);
        let per = read_sysfs_param("periods").unwrap_or_default().trim().parse::<u32>().unwrap_or(0);

        let mut live_buf = buf;
        let mut live_rate = rate;

        if let Ok(card) = get_asnux_card_num() {
            if let Ok(val) = get_alsa_value(card, "ASNUX Buffer Size") {
                live_buf = val.parse().unwrap_or(buf);
            }
            if let Ok(val) = get_alsa_value(card, "ASNUX Sample Rate") {
                live_rate = val.parse().unwrap_or(rate);
            }
        }

        status["buffer_size"] = serde_json::json!(live_buf);
        status["sample_rate"] = serde_json::json!(live_rate);
        status["channels"] = serde_json::json!(ch);
        status["periods"] = serde_json::json!(per);
    }

    Ok(status)
}

fn set_default_engine(enable: bool) -> Result<()> {
    let pulse_cfg = "/etc/pulse/default.pa";
    let asnux_line = "load-module module-alsa-sink device_id=asnux";

    if !Path::new(pulse_cfg).exists() {
        anyhow::bail!("PulseAudio config not found at {}", pulse_cfg);
    }

    let content = fs::read_to_string(pulse_cfg)
        .with_context(|| format!("Failed to read {}", pulse_cfg))?;

    if enable {
        info!("Setting ASNUX as default audio engine");

        if content.contains("device_id=asnux") {
            info!("ASNUX already configured in PulseAudio");
            return Ok(());
        }

        std::fs::write(format!("{}.bak", pulse_cfg), &content)
            .with_context(|| "Cannot create backup of PulseAudio config")?;

        let new_content = format!("{}\n{}", content, asnux_line);
        fs::write(pulse_cfg, &new_content)
            .context("Cannot write PulseAudio configuration")?;

        info!("ASNUX added to PulseAudio config");
    } else {
        info!("Removing ASNUX from default audio engine");

        let filtered: Vec<&str> = content
            .lines()
            .filter(|line| !line.contains("device_id=asnux"))
            .collect();

        if filtered.join("\n") != content {
            std::fs::write(format!("{}.bak", pulse_cfg), &content)
                .with_context(|| "Cannot create backup of PulseAudio config")?;
        }

        fs::write(pulse_cfg, filtered.join("\n"))
            .context("Cannot update PulseAudio configuration")?;

        info!("ASNUX removed from PulseAudio config");
    }
    Ok(())
}

fn respond_error(stream: &mut std::os::unix::net::UnixStream, msg: &str) {
    let resp = Response {
        status: "error".to_string(),
        data: serde_json::json!({}),
        error: Some(msg.to_string()),
    };
    if let Ok(json) = serde_json::to_string(&resp) {
        let _ = stream.write_all(json.as_bytes());
        let _ = stream.write_all(b"\n");
    }
}

fn handle_client(mut stream: std::os::unix::net::UnixStream) {
    let mut reader = BufReader::new(&mut stream);
    let mut buf = String::new();

    match reader.read_line(&mut buf) {
        Ok(0) => {}
        Err(e) => {
            warn!("Client read error: {}", e);
        }
        Ok(_) => {
            let request: Request = match serde_json::from_str(buf.trim()) {
                Ok(r) => r,
                Err(e) => {
                    let resp = Response {
                        status: "error".to_string(),
                        data: serde_json::json!({}),
                        error: Some(format!("Invalid request: {}", e)),
                    };
                    let _ = stream.write_all(
                        serde_json::to_string(&resp).unwrap().as_bytes(),
                    );
                    let _ = stream.write_all(b"\n");
                    return;
                }
            };

            info!("Request received: {}", request.method);

            let response = match request.method.as_str() {
                "load" => {
                    let config: Config = match serde_json::from_value(request.params) {
                        Ok(c) => c,
                        Err(e) => return respond_error(&mut stream, &format!("Invalid config: {}", e)),
                    };
                    match load_module(&config) {
                        Ok(_) => Response {
                            status: "ok".to_string(),
                            data: serde_json::json!({"message": "Module loaded"}),
                            error: None,
                        },
                        Err(e) => Response {
                            status: "error".to_string(),
                            data: serde_json::json!({}),
                            error: Some(e.to_string()),
                        },
                    }
                }
                "unload" => {
                    match unload_module() {
                        Ok(_) => Response {
                            status: "ok".to_string(),
                            data: serde_json::json!({"message": "Module unloaded"}),
                            error: None,
                        },
                        Err(e) => Response {
                            status: "error".to_string(),
                            data: serde_json::json!({}),
                            error: Some(e.to_string()),
                        },
                    }
                }
                "configure" => {
                    let config: Config = match serde_json::from_value(request.params) {
                        Ok(c) => c,
                        Err(e) => return respond_error(&mut stream, &format!("Invalid config: {}", e)),
                    };
                    match apply_config(&config) {
                        Ok(_) => Response {
                            status: "ok".to_string(),
                            data: serde_json::json!({"message": "Config applied"}),
                            error: None,
                        },
                        Err(e) => Response {
                            status: "error".to_string(),
                            data: serde_json::json!({}),
                            error: Some(e.to_string()),
                        },
                    }
                }
                "status" => {
                    match get_status() {
                        Ok(data) => Response {
                            status: "ok".to_string(),
                            data,
                            error: None,
                        },
                        Err(e) => Response {
                            status: "error".to_string(),
                            data: serde_json::json!({}),
                            error: Some(e.to_string()),
                        },
                    }
                }
                "list_cards" => {
                    match list_cards() {
                        Ok(data) => Response {
                            status: "ok".to_string(),
                            data,
                            error: None,
                        },
                        Err(e) => Response {
                            status: "error".to_string(),
                            data: serde_json::json!({}),
                            error: Some(e.to_string()),
                        },
                    }
                }
                "set_default_engine" => {
                    let enable = request.params.get("enable")
                        .and_then(|v| v.as_bool())
                        .unwrap_or(false);
                    match set_default_engine(enable) {
                        Ok(_) => Response {
                            status: "ok".to_string(),
                            data: serde_json::json!({"message": if enable {
                                "ASNUX set as default engine"
                            } else {
                                "Default engine disabled"
                            }}),
                            error: None,
                        },
                        Err(e) => Response {
                            status: "error".to_string(),
                            data: serde_json::json!({}),
                            error: Some(e.to_string()),
                        },
                    }
                }
                _ => Response {
                    status: "error".to_string(),
                    data: serde_json::json!({}),
                    error: Some(format!("Unknown method: {}", request.method)),
                },
            };

            if let Ok(resp_str) = serde_json::to_string(&response) {
                let _ = stream.write_all(resp_str.as_bytes());
                let _ = stream.write_all(b"\n");
            } else {
                error!("Failed to serialize response");
            }
        }
    }
}

fn run_daemon() -> Result<()> {
    let socket_dir = Path::new(SOCKET_PATH).parent().unwrap();
    fs::create_dir_all(socket_dir)
        .context("Cannot create socket directory")?;
    fs::set_permissions(socket_dir, fs::Permissions::from_mode(0o755))
        .ok();

    if Path::new(SOCKET_PATH).exists() {
        fs::remove_file(SOCKET_PATH)
            .context("Cannot remove old socket")?;
    }

    let listener = std::os::unix::net::UnixListener::bind(SOCKET_PATH)
        .context("Cannot create Unix socket")?;

    fs::set_permissions(SOCKET_PATH, fs::Permissions::from_mode(0o666))
        .context("Cannot change socket permissions")?;

    info!("ASNUX daemon listening on {}", SOCKET_PATH);

    let running = Arc::new(AtomicBool::new(true));
    let r = running.clone();

    ctrlc::set_handler(move || {
        info!("Shutdown signal received");
        r.store(false, Ordering::SeqCst);
    })
    .ok();

    listener.set_nonblocking(true)?;

    while running.load(Ordering::SeqCst) {
        match listener.accept() {
            Ok((stream, _)) => {
                handle_client(stream);
            }
            Err(ref e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                std::thread::sleep(std::time::Duration::from_millis(100));
            }
            Err(e) => {
                error!("Connection error: {}", e);
            }
        }
    }

    let _ = fs::remove_file(SOCKET_PATH);
    info!("Daemon stopped");
    Ok(())
}

fn main() {
    env_logger::Builder::from_env(
        env_logger::Env::default().default_filter_or("info"),
    )
    .init();

    info!("ASNUX Daemon v{}", env!("CARGO_PKG_VERSION"));

    match run_daemon() {
        Ok(_) => info!("Daemon finished"),
        Err(e) => error!("Fatal error: {}", e),
    }
}
