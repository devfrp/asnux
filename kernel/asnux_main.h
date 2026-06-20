#ifndef _ASNUX_MAIN_H
#define _ASNUX_MAIN_H

#include <linux/module.h>
#include <linux/moduleparam.h>
#include <linux/platform_device.h>
#include <linux/device.h>
#include <linux/mutex.h>
#include <sound/core.h>
#include <sound/pcm.h>
#include <sound/initval.h>
#include <sound/control.h>

#define DRIVER_NAME "asnux"
#define DRIVER_VERSION "1.0.1"

#define ASNUX_MAX_CARDS 8
#define ASNUX_DEFAULT_BUFFER_SIZE 256
#define ASNUX_MIN_BUFFER_SIZE 16
#define ASNUX_MAX_BUFFER_SIZE 8192
#define ASNUX_DEFAULT_SAMPLE_RATE 48000
#define ASNUX_MIN_SAMPLE_RATE 8000
#define ASNUX_MAX_SAMPLE_RATE 192000
#define ASNUX_DEFAULT_CHANNELS 2
#define ASNUX_MAX_CHANNELS 8
#define ASNUX_MIN_PERIODS 2
#define ASNUX_MAX_PERIODS 1024
#define ASNUX_DEFAULT_PERIODS 4

struct asnux_card {
	struct snd_card *card;
	struct snd_pcm *pcm;
	int index;
	int buffer_size;
	int sample_rate;
	int channels;
	int periods;
	int period_size;
	struct mutex lock;
};

extern int asnux_buffer_size;
extern int asnux_sample_rate;
extern int asnux_channels;
extern int asnux_periods;

extern const struct snd_pcm_ops asnux_pcm_ops;
extern const struct snd_pcm_hardware asnux_pcm_hardware;

int asnux_create_controls(struct asnux_card *acard);

#endif /* _ASNUX_MAIN_H */
