use eframe::egui;
use serde::{Deserialize, Serialize};
use std::io::{BufRead, BufReader, Write};
use std::os::unix::net::UnixStream;
use std::sync::mpsc;
use std::thread;

#[derive(Debug, Clone, Serialize, Deserialize)]
struct Config {
    buffer_size: u32,
    sample_rate: u32,
    channels: u32,
    periods: u32,
    default_engine: bool,
    realtime_priority: i32,
}

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

#[derive(Debug, Clone, Serialize, Deserialize)]
struct DaemonStatus {
    module_loaded: bool,
    buffer_size: Option<u32>,
    sample_rate: Option<u32>,
    channels: Option<u32>,
    periods: Option<u32>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct Request {
    method: String,
    params: serde_json::Value,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct Response {
    status: String,
    data: serde_json::Value,
    error: Option<String>,
}

#[derive(Debug, Clone)]
enum DaemonMsg {
    Status(DaemonStatus),
    CardList(Vec<SoundCard>),
    Error(String),
    Success(String),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
struct SoundCard {
    index: u32,
    name: String,
    description: String,
    max_channels: u32,
}

const SOCKET_PATH: &str = "/run/asnux/asnux-daemon.sock";

fn send_request(method: &str, params: serde_json::Value) -> Result<Response, String> {
    let mut stream =
        UnixStream::connect(SOCKET_PATH).map_err(|e| format!("Cannot connect to daemon: {}", e))?;

    let req = Request {
        method: method.to_string(),
        params,
    };

    let mut req_str =
        serde_json::to_string(&req).map_err(|e| format!("Serialization error: {}", e))?;
    req_str.push('\n');

    stream
        .write_all(req_str.as_bytes())
        .map_err(|e| format!("Write error: {}", e))?;

    let mut reader = BufReader::new(&mut stream);
    let mut line = String::new();
    reader
        .read_line(&mut line)
        .map_err(|e| format!("Read error: {}", e))?;

    let resp: Response = serde_json::from_str(line.trim())
        .map_err(|e| format!("Parse error: {} — received: {}", e, line.trim()))?;

    if resp.status == "error" {
        Err(resp.error.unwrap_or_else(|| "Unknown error".to_string()))
    } else {
        Ok(resp)
    }
}

fn get_daemon_status() -> Result<DaemonStatus, String> {
    let resp = send_request("status", serde_json::json!({}))?;
    let data = &resp.data;

    Ok(DaemonStatus {
        module_loaded: data
            .get("module_loaded")
            .and_then(|v| v.as_bool())
            .unwrap_or(false),
        buffer_size: data
            .get("buffer_size")
            .and_then(|v| v.as_u64())
            .map(|v| v as u32),
        sample_rate: data
            .get("sample_rate")
            .and_then(|v| v.as_u64())
            .map(|v| v as u32),
        channels: data
            .get("channels")
            .and_then(|v| v.as_u64())
            .map(|v| v as u32),
        periods: data
            .get("periods")
            .and_then(|v| v.as_u64())
            .map(|v| v as u32),
    })
}

fn apply_config(config: &Config) -> Result<(), String> {
    let params = serde_json::to_value(config).map_err(|e| format!("Serialization error: {}", e))?;
    send_request("configure", params)?;
    Ok(())
}

fn load_module(config: &Config) -> Result<(), String> {
    let params = serde_json::to_value(config).map_err(|e| format!("Serialization error: {}", e))?;
    send_request("load", params)?;
    Ok(())
}

fn unload_module() -> Result<(), String> {
    send_request("unload", serde_json::json!({}))?;
    Ok(())
}

fn set_default_engine(enable: bool) -> Result<(), String> {
    send_request("set_default_engine", serde_json::json!({"enable": enable}))?;
    Ok(())
}

fn list_cards() -> Result<Vec<SoundCard>, String> {
    let resp = send_request("list_cards", serde_json::json!({}))?;
    let cards: Vec<SoundCard> =
        serde_json::from_value(resp.data).map_err(|e| format!("Parse error: {}", e))?;
    Ok(cards)
}

struct AsnuxApp {
    config: Config,
    status: Option<DaemonStatus>,
    status_msg: String,
    status_is_error: bool,
    pending_count: u32,
    config_dirty: bool,
    need_refresh: bool,
    cards: Vec<SoundCard>,
    selected_card_index: usize,
    channel_rx: mpsc::Receiver<DaemonMsg>,
    channel_tx: mpsc::SyncSender<DaemonMsg>,
}

impl AsnuxApp {
    fn new() -> Self {
        let (tx, rx) = mpsc::sync_channel::<DaemonMsg>(8);
        let mut app = Self {
            config: Config::default(),
            status: None,
            status_msg: String::new(),
            status_is_error: false,
            pending_count: 0,
            config_dirty: false,
            need_refresh: false,
            cards: Vec::new(),
            selected_card_index: 0,
            channel_rx: rx,
            channel_tx: tx,
        };
        app.refresh_status();
        app.refresh_cards();
        app
    }

    fn refresh_cards(&mut self) {
        let tx = self.channel_tx.clone();
        self.pending_count += 1;
        thread::spawn(move || match list_cards() {
            Ok(cards) => {
                let _ = tx.send(DaemonMsg::CardList(cards));
            }
            Err(e) => {
                let _ = tx.send(DaemonMsg::Error(e));
            }
        });
    }

    fn refresh_status(&mut self) {
        let tx = self.channel_tx.clone();
        self.pending_count += 1;
        thread::spawn(move || match get_daemon_status() {
            Ok(status) => {
                let _ = tx.send(DaemonMsg::Status(status));
            }
            Err(e) => {
                let _ = tx.send(DaemonMsg::Error(format!("Error: {}", e)));
            }
        });
    }

    fn send_load(&mut self) {
        let tx = self.channel_tx.clone();
        let config = self.config.clone();
        self.pending_count += 1;
        thread::spawn(move || match load_module(&config) {
            Ok(_) => {
                let _ = tx.send(DaemonMsg::Success("Module loaded".into()));
            }
            Err(e) => {
                let _ = tx.send(DaemonMsg::Error(format!("Load failed: {}", e)));
            }
        });
    }

    fn send_unload(&mut self) {
        let tx = self.channel_tx.clone();
        self.pending_count += 1;
        thread::spawn(move || match unload_module() {
            Ok(_) => {
                let _ = tx.send(DaemonMsg::Success("Module unloaded".into()));
            }
            Err(e) => {
                let _ = tx.send(DaemonMsg::Error(format!("Unload failed: {}", e)));
            }
        });
    }

    fn send_configure(&mut self) {
        let tx = self.channel_tx.clone();
        let config = self.config.clone();
        self.pending_count += 1;
        self.config_dirty = false;
        thread::spawn(move || match apply_config(&config) {
            Ok(_) => {
                let _ = tx.send(DaemonMsg::Success("Config applied".into()));
            }
            Err(e) => {
                let _ = tx.send(DaemonMsg::Error(format!("Config failed: {}", e)));
            }
        });
    }

    fn send_default_engine(&mut self) {
        let tx = self.channel_tx.clone();
        let enable = self.config.default_engine;
        self.pending_count += 1;
        thread::spawn(move || match set_default_engine(enable) {
            Ok(_) => {
                let _ = tx.send(DaemonMsg::Success(
                    if enable {
                        "ASNUX set as default engine"
                    } else {
                        "Default engine disabled"
                    }
                    .into(),
                ));
            }
            Err(e) => {
                let _ = tx.send(DaemonMsg::Error(format!("Failed: {}", e)));
            }
        });
    }
}

impl eframe::App for AsnuxApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        while let Ok(msg) = self.channel_rx.try_recv() {
            if self.pending_count > 0 {
                self.pending_count -= 1;
            }
            match msg {
                DaemonMsg::Status(status) => {
                    self.status = Some(status.clone());
                    self.status_msg = "Connected to ASNUX daemon".to_string();
                    self.status_is_error = false;

                    if !self.config_dirty {
                        if let (Some(buf), Some(rate), Some(ch), Some(per)) = (
                            status.buffer_size,
                            status.sample_rate,
                            status.channels,
                            status.periods,
                        ) {
                            self.config.buffer_size = buf;
                            self.config.sample_rate = rate;
                            self.config.channels = ch;
                            self.config.periods = per;
                        }
                    }
                }
                DaemonMsg::CardList(cards) => {
                    if !cards.is_empty() && self.selected_card_index >= cards.len() {
                        self.selected_card_index = 0;
                    }
                    self.cards = cards;
                }
                DaemonMsg::Error(e) => {
                    self.status_msg = e;
                    self.status_is_error = true;
                }
                DaemonMsg::Success(msg) => {
                    self.status_msg = msg;
                    self.status_is_error = false;
                    self.need_refresh = true;
                }
            }
        }

        if self.need_refresh && self.pending_count == 0 {
            self.need_refresh = false;
            self.refresh_status();
        }

        egui::CentralPanel::default().show(ctx, |ui| {
            egui::ScrollArea::vertical().show(ui, |ui| {
                ui.heading("ASNUX Audio Engine");
                ui.label("Low-latency audio configuration for Linux");
                ui.separator();

                if self.status_msg.is_empty() {
                    ui.label("Connecting to daemon...");
                } else {
                    let color = if self.status_is_error {
                        egui::Color32::RED
                    } else {
                        egui::Color32::GREEN
                    };
                    ui.colored_label(color, &self.status_msg);
                }

                ui.separator();

                if !self.cards.is_empty() && self.selected_card_index < self.cards.len() {
                    let max_ch = self.cards[self.selected_card_index].max_channels;
                    if self.config.channels > max_ch {
                        self.config.channels = max_ch;
                    }
                    ui.horizontal(|ui| {
                        ui.label("Sound card:");
                        egui::ComboBox::from_id_source("card_selector")
                            .selected_text(
                                if !self.cards[self.selected_card_index].description.is_empty() {
                                    self.cards[self.selected_card_index].description.clone()
                                } else {
                                    self.cards[self.selected_card_index].name.clone()
                                },
                            )
                            .show_ui(ui, |ui| {
                                for (i, card) in self.cards.iter().enumerate() {
                                    let label = if card.description.is_empty() {
                                        format!("{} ({} canaux)", card.name, card.max_channels)
                                    } else {
                                        format!(
                                            "{} — {} ({} canaux)",
                                            card.name, card.description, card.max_channels
                                        )
                                    };
                                    ui.selectable_value(&mut self.selected_card_index, i, label);
                                }
                            });
                        if ui.button("↻").clicked() {
                            self.refresh_cards();
                        }
                    });
                }

                ui.horizontal(|ui| {
                    if ui.button("Refresh").clicked() {
                        self.refresh_status();
                    }
                    if self.pending_count > 0 {
                        ui.spinner();
                    }
                });

                ui.separator();

                egui::Frame::group(ui.style())
                    .inner_margin(egui::Margin::symmetric(8.0, 8.0))
                    .show(ui, |ui| {
                        ui.heading("Audio engine configuration");
                        ui.separator();

                        if ui
                            .add(
                                egui::Slider::new(&mut self.config.buffer_size, 16..=8192)
                                    .text("Buffer size (samples)"),
                            )
                            .changed()
                        {
                            self.config_dirty = true;
                        }

                        let latency_ms = (self.config.buffer_size as f64
                            * self.config.periods as f64
                            / self.config.sample_rate as f64)
                            * 1000.0;
                        ui.label(format!("Estimated latency: {:.1} ms", latency_ms));

                        let rates = [
                            8000, 11025, 16000, 22050, 32000, 44100, 48000, 64000, 88200, 96000,
                            176400, 192000,
                        ];
                        let rate_strs: Vec<String> = rates
                            .iter()
                            .map(|r| match r {
                                44100 => "44100 Hz (CD quality)".to_string(),
                                48000 => "48000 Hz (Studio)".to_string(),
                                96000 => "96000 Hz (High resolution)".to_string(),
                                192000 => "192000 Hz (Ultra HD)".to_string(),
                                _ => format!("{} Hz", r),
                            })
                            .collect();
                        let rate_labels: Vec<&str> = rate_strs.iter().map(|s| s.as_str()).collect();
                        let mut rate_idx = rates
                            .iter()
                            .position(|r| *r == self.config.sample_rate)
                            .unwrap_or(6);
                        if egui::ComboBox::from_label("Sample rate")
                            .selected_text(rate_labels[rate_idx])
                            .show_ui(ui, |ui| {
                                for (i, label) in rate_labels.iter().enumerate() {
                                    ui.selectable_value(&mut rate_idx, i, *label);
                                }
                            })
                            .response
                            .changed()
                        {
                            self.config_dirty = true;
                        }
                        self.config.sample_rate = rates[rate_idx];

                        ui.horizontal(|ui| {
                            let max_ch = if self.selected_card_index < self.cards.len() {
                                self.cards[self.selected_card_index].max_channels
                            } else {
                                2
                            };
                            if ui
                                .add(
                                    egui::Slider::new(&mut self.config.channels, 1..=max_ch)
                                        .text("Channels"),
                                )
                                .changed()
                            {
                                self.config_dirty = true;
                            }
                            let ch_label = match self.config.channels {
                                1 => "Mono",
                                2 => "Stereo",
                                4 => "Quad",
                                6 => "5.1",
                                8 => "7.1",
                                _ => "",
                            };
                            if !ch_label.is_empty() {
                                ui.label(ch_label);
                            }
                        });

                        let periods_vals = [2, 4, 8, 16, 32];
                        let mut per_idx = periods_vals
                            .iter()
                            .position(|p| *p == self.config.periods)
                            .unwrap_or(1);
                        if egui::ComboBox::from_label("Periods")
                            .selected_text(format!("{} periods", self.config.periods))
                            .show_ui(ui, |ui| {
                                for (i, &p) in periods_vals.iter().enumerate() {
                                    ui.selectable_value(&mut per_idx, i, format!("{} periods", p));
                                }
                            })
                            .response
                            .changed()
                        {
                            self.config_dirty = true;
                        }
                        self.config.periods = periods_vals[per_idx];
                    });

                ui.separator();

                egui::Frame::group(ui.style())
                    .inner_margin(egui::Margin::symmetric(8.0, 8.0))
                    .show(ui, |ui| {
                        ui.heading("Default audio engine");
                        ui.checkbox(
                            &mut self.config.default_engine,
                            "Use ASNUX as default audio engine",
                        );
                        if self.config.default_engine {
                            ui.label("ASNUX will be the primary system audio device");
                        }
                    });

                ui.separator();

                let pending = self.pending_count > 0;
                ui.horizontal(|ui| {
                    if ui
                        .add_enabled(!pending, egui::Button::new("Load module"))
                        .clicked()
                    {
                        self.send_load();
                    }
                    if ui
                        .add_enabled(!pending, egui::Button::new("Apply config"))
                        .clicked()
                    {
                        self.send_configure();
                    }
                    if ui
                        .add_enabled(!pending, egui::Button::new("Unload module"))
                        .clicked()
                    {
                        self.send_unload();
                    }
                });

                if ui
                    .add_enabled(!pending, egui::Button::new("Apply default engine"))
                    .clicked()
                {
                    self.send_default_engine();
                }

                ui.separator();

                if let Some(status) = &self.status {
                    ui.heading("Device status");
                    if status.module_loaded {
                        ui.label(egui::RichText::new("Module: LOADED").color(egui::Color32::GREEN));
                        if let Some(buf) = status.buffer_size {
                            ui.label(format!("Buffer: {} samples", buf));
                        }
                        if let Some(rate) = status.sample_rate {
                            ui.label(format!("Rate: {} Hz", rate));
                        }
                        if let Some(ch) = status.channels {
                            ui.label(format!("Channels: {}", ch));
                        }
                        if let Some(per) = status.periods {
                            ui.label(format!("Periods: {}", per));
                        }
                    } else {
                        ui.label(
                            egui::RichText::new("Module: NOT LOADED").color(egui::Color32::RED),
                        );
                    }
                }

                ui.separator();
                ui.hyperlink_to("Documentation", "https://github.com/devfrp/asnux");
                ui.label(format!("ASNUX v{}", env!("CARGO_PKG_VERSION")));
            });
        });
    }
}

fn main() -> Result<(), eframe::Error> {
    env_logger::init();

    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_inner_size([480.0, 700.0])
            .with_title("ASNUX Audio Engine"),
        ..Default::default()
    };

    eframe::run_native(
        "ASNUX Audio Engine",
        options,
        Box::new(|_cc| Ok(Box::new(AsnuxApp::new()))),
    )
}
