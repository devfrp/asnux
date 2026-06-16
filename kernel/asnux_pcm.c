#include "asnux_main.h"
#include <linux/vmalloc.h>
#include <linux/timer.h>
#include <linux/jiffies.h>
#include <linux/version.h>

#if LINUX_VERSION_CODE < KERNEL_VERSION(6, 4, 0)
#define timer_delete(t) del_timer(t)
#define timer_delete_sync(t) del_timer_sync(t)
#endif

struct asnux_pcm_data {
	struct asnux_card *acard;
	struct snd_pcm_substream *substream;
	unsigned long buf_pos;
	void *buf;
	int buf_size;
	struct timer_list timer;
	unsigned long period_jiffies;
};

static void asnux_timer_callback(struct timer_list *t)
{
	struct asnux_pcm_data *data = container_of(t, struct asnux_pcm_data, timer);
	struct snd_pcm_substream *substream = data->substream;
	struct snd_pcm_runtime *runtime = substream->runtime;

	if (!data->buf)
		return;

	data->buf_pos += frames_to_bytes(runtime, runtime->period_size);
	if (data->buf_pos >= data->buf_size)
		data->buf_pos %= data->buf_size;

	snd_pcm_period_elapsed(substream);

	mod_timer(&data->timer, jiffies + data->period_jiffies);
}

const struct snd_pcm_hardware asnux_pcm_hardware = {
	.info = SNDRV_PCM_INFO_MMAP |
		SNDRV_PCM_INFO_MMAP_VALID |
		SNDRV_PCM_INFO_INTERLEAVED |
		SNDRV_PCM_INFO_BLOCK_TRANSFER |
		SNDRV_PCM_INFO_BATCH,

	.formats = SNDRV_PCM_FMTBIT_S16_LE |
		   SNDRV_PCM_FMTBIT_S24_LE |
		   SNDRV_PCM_FMTBIT_S32_LE |
		   SNDRV_PCM_FMTBIT_FLOAT_LE,

	.rates = SNDRV_PCM_RATE_8000_192000,

	.rate_min = ASNUX_MIN_SAMPLE_RATE,
	.rate_max = ASNUX_MAX_SAMPLE_RATE,

	.channels_min = 1,
	.channels_max = ASNUX_MAX_CHANNELS,

	.buffer_bytes_max = ASNUX_MAX_BUFFER_SIZE * ASNUX_MAX_CHANNELS * 4,
	.period_bytes_min = 32,
	.period_bytes_max = ASNUX_MAX_BUFFER_SIZE * ASNUX_MAX_CHANNELS * 4 / ASNUX_MIN_PERIODS,
	.periods_min = ASNUX_MIN_PERIODS,
	.periods_max = ASNUX_MAX_PERIODS,
};

static int asnux_pcm_open(struct snd_pcm_substream *substream)
{
	struct snd_pcm_runtime *runtime = substream->runtime;
	struct asnux_card *acard = substream->pcm->private_data;
	struct asnux_pcm_data *data;

	data = kzalloc(sizeof(*data), GFP_KERNEL);
	if (!data)
		return -ENOMEM;

	data->acard = acard;
	data->substream = substream;
	data->buf = NULL;

	runtime->private_data = data;
	runtime->hw = asnux_pcm_hardware;

	snd_pcm_hw_constraint_minmax(runtime,
				     SNDRV_PCM_HW_PARAM_BUFFER_SIZE,
				     ASNUX_MIN_BUFFER_SIZE,
				     ASNUX_MAX_BUFFER_SIZE);
	snd_pcm_hw_constraint_minmax(runtime,
				     SNDRV_PCM_HW_PARAM_PERIOD_SIZE,
				     16,
				     ASNUX_MAX_BUFFER_SIZE / ASNUX_MIN_PERIODS);
	snd_pcm_hw_constraint_integer(runtime,
				      SNDRV_PCM_HW_PARAM_PERIODS);

	return 0;
}

static int asnux_pcm_close(struct snd_pcm_substream *substream)
{
	struct asnux_pcm_data *data = substream->runtime->private_data;

	timer_delete_sync(&data->timer);
	if (data->buf)
		vfree(data->buf);
	kfree(data);
	return 0;
}

static int asnux_pcm_hw_params(struct snd_pcm_substream *substream,
			       struct snd_pcm_hw_params *hw_params)
{
	struct asnux_pcm_data *data = substream->runtime->private_data;
	int buf_size = params_buffer_bytes(hw_params);
	unsigned long period_us;

	if (data->buf)
		vfree(data->buf);

	data->buf = vmalloc(buf_size);
	if (!data->buf)
		return -ENOMEM;

	data->buf_size = buf_size;
	data->buf_pos = 0;

	period_us = (params_period_size(hw_params) * 1000000UL) / params_rate(hw_params);
	data->period_jiffies = usecs_to_jiffies(period_us);
	if (data->period_jiffies == 0)
		data->period_jiffies = 1;

	timer_setup(&data->timer, asnux_timer_callback, 0);

	return 0;
}

static int asnux_pcm_hw_free(struct snd_pcm_substream *substream)
{
	struct asnux_pcm_data *data = substream->runtime->private_data;
	if (data->buf) {
		vfree(data->buf);
		data->buf = NULL;
	}
	return 0;
}

static int asnux_pcm_prepare(struct snd_pcm_substream *substream)
{
	struct asnux_pcm_data *data = substream->runtime->private_data;
	if (!data->buf)
		return -ENXIO;
	data->buf_pos = 0;
	return 0;
}

static int asnux_pcm_trigger(struct snd_pcm_substream *substream, int cmd)
{
	struct asnux_pcm_data *data = substream->runtime->private_data;

	switch (cmd) {
	case SNDRV_PCM_TRIGGER_START:
		mod_timer(&data->timer, jiffies + data->period_jiffies);
		return 0;
	case SNDRV_PCM_TRIGGER_STOP:
	case SNDRV_PCM_TRIGGER_DRAIN:
	case SNDRV_PCM_TRIGGER_SUSPEND:
		timer_delete(&data->timer);
		return 0;
	case SNDRV_PCM_TRIGGER_PAUSE_PUSH:
	case SNDRV_PCM_TRIGGER_PAUSE_RELEASE:
		return 0;
	default:
		return -EINVAL;
	}
}

static snd_pcm_uframes_t asnux_pcm_pointer(struct snd_pcm_substream *substream)
{
	struct asnux_pcm_data *data = substream->runtime->private_data;
	if (!data->buf)
		return 0;
	return bytes_to_frames(substream->runtime, data->buf_pos % data->buf_size);
}

static int asnux_pcm_copy(struct snd_pcm_substream *substream, int channel,
			  unsigned long pos, struct iov_iter *iter,
			  unsigned long bytes)
{
	struct asnux_pcm_data *data = substream->runtime->private_data;
	unsigned long byte_pos;

	if (!data->buf)
		return -ENXIO;

	byte_pos = frames_to_bytes(substream->runtime, pos) % data->buf_size;

	if (byte_pos + bytes > data->buf_size)
		bytes = data->buf_size - byte_pos;

	if (substream->stream == SNDRV_PCM_STREAM_PLAYBACK) {
		if (copy_from_iter(data->buf + byte_pos, bytes, iter))
			return -EFAULT;
	} else {
		if (copy_to_iter(data->buf + byte_pos, bytes, iter))
			return -EFAULT;
	}

	return 0;
}

static int asnux_pcm_silence(struct snd_pcm_substream *substream, int channel,
			     unsigned long pos, unsigned long bytes)
{
	struct asnux_pcm_data *data = substream->runtime->private_data;
	unsigned long byte_pos;

	if (!data->buf)
		return -ENXIO;

	byte_pos = frames_to_bytes(substream->runtime, pos) % data->buf_size;

	if (byte_pos + bytes > data->buf_size)
		bytes = data->buf_size - byte_pos;

	memset(data->buf + byte_pos, 0, bytes);

	return 0;
}

static int asnux_pcm_mmap(struct snd_pcm_substream *substream,
			  struct vm_area_struct *vma)
{
	return snd_pcm_lib_default_mmap(substream, vma);
}

static struct page *asnux_pcm_page(struct snd_pcm_substream *substream,
				   unsigned long offset)
{
	struct asnux_pcm_data *data = substream->runtime->private_data;
	if (!data->buf)
		return NULL;
	return vmalloc_to_page(data->buf + offset);
}

const struct snd_pcm_ops asnux_pcm_ops = {
	.open = asnux_pcm_open,
	.close = asnux_pcm_close,
	.hw_params = asnux_pcm_hw_params,
	.hw_free = asnux_pcm_hw_free,
	.prepare = asnux_pcm_prepare,
	.trigger = asnux_pcm_trigger,
	.pointer = asnux_pcm_pointer,
	.copy = asnux_pcm_copy,
	.fill_silence = asnux_pcm_silence,
	.mmap = asnux_pcm_mmap,
	.page = asnux_pcm_page,
};
