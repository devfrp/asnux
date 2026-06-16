#include "asnux_main.h"

static const int asnux_sample_rates[] = {
	8000, 11025, 16000, 22050, 32000, 44100,
	48000, 64000, 88200, 96000, 176400, 192000
};

static const char * const asnux_sample_rate_names[] = {
	"8000", "11025", "16000", "22050", "32000", "44100",
	"48000", "64000", "88200", "96000", "176400", "192000"
};

static int asnux_ctl_buffer_size_info(struct snd_kcontrol *kcontrol,
				      struct snd_ctl_elem_info *uinfo)
{
	uinfo->type = SNDRV_CTL_ELEM_TYPE_INTEGER;
	uinfo->count = 1;
	uinfo->value.integer.min = ASNUX_MIN_BUFFER_SIZE;
	uinfo->value.integer.max = ASNUX_MAX_BUFFER_SIZE;
	uinfo->value.integer.step = 16;
	return 0;
}

static int asnux_ctl_buffer_size_get(struct snd_kcontrol *kcontrol,
				     struct snd_ctl_elem_value *ucontrol)
{
	struct asnux_card *acard = snd_kcontrol_chip(kcontrol);
	mutex_lock(&acard->lock);
	ucontrol->value.integer.value[0] = acard->buffer_size;
	mutex_unlock(&acard->lock);
	return 0;
}

static int asnux_ctl_buffer_size_put(struct snd_kcontrol *kcontrol,
				     struct snd_ctl_elem_value *ucontrol)
{
	struct asnux_card *acard = snd_kcontrol_chip(kcontrol);
	int val = clamp_t(int, ucontrol->value.integer.value[0],
			  ASNUX_MIN_BUFFER_SIZE, ASNUX_MAX_BUFFER_SIZE);

	mutex_lock(&acard->lock);
	if (acard->buffer_size == val) {
		mutex_unlock(&acard->lock);
		return 0;
	}
	acard->buffer_size = val;
	acard->period_size = val / acard->periods;
	mutex_unlock(&acard->lock);
	return 1;
}

static int asnux_ctl_sample_rate_info(struct snd_kcontrol *kcontrol,
				      struct snd_ctl_elem_info *uinfo)
{
	int idx;

	uinfo->type = SNDRV_CTL_ELEM_TYPE_ENUMERATED;
	uinfo->count = 1;
	uinfo->value.enumerated.items = ARRAY_SIZE(asnux_sample_rates);

	idx = uinfo->value.enumerated.item;
	if (idx >= ARRAY_SIZE(asnux_sample_rates))
		idx = ARRAY_SIZE(asnux_sample_rates) - 1;

	strncpy(uinfo->value.enumerated.name,
		asnux_sample_rate_names[idx],
		sizeof(uinfo->value.enumerated.name));

	return 0;
}

static int asnux_ctl_sample_rate_get(struct snd_kcontrol *kcontrol,
				     struct snd_ctl_elem_value *ucontrol)
{
	struct asnux_card *acard = snd_kcontrol_chip(kcontrol);
	int i;

	mutex_lock(&acard->lock);
	for (i = 0; i < ARRAY_SIZE(asnux_sample_rates); i++) {
		if (asnux_sample_rates[i] == acard->sample_rate) {
			ucontrol->value.enumerated.item[0] = i;
			break;
		}
	}
	mutex_unlock(&acard->lock);
	return 0;
}

static int asnux_ctl_sample_rate_put(struct snd_kcontrol *kcontrol,
				     struct snd_ctl_elem_value *ucontrol)
{
	struct asnux_card *acard = snd_kcontrol_chip(kcontrol);
	int idx = clamp_t(int, ucontrol->value.enumerated.item[0], 0,
			  ARRAY_SIZE(asnux_sample_rates) - 1);
	int rate = asnux_sample_rates[idx];

	mutex_lock(&acard->lock);
	if (acard->sample_rate == rate) {
		mutex_unlock(&acard->lock);
		return 0;
	}
	acard->sample_rate = rate;
	mutex_unlock(&acard->lock);
	return 1;
}

static const struct snd_kcontrol_new asnux_controls[] = {
	{
		.iface = SNDRV_CTL_ELEM_IFACE_MIXER,
		.name = "ASNUX Buffer Size",
		.info = asnux_ctl_buffer_size_info,
		.get = asnux_ctl_buffer_size_get,
		.put = asnux_ctl_buffer_size_put,
	},
	{
		.iface = SNDRV_CTL_ELEM_IFACE_MIXER,
		.name = "ASNUX Sample Rate",
		.info = asnux_ctl_sample_rate_info,
		.get = asnux_ctl_sample_rate_get,
		.put = asnux_ctl_sample_rate_put,
	},
};

int asnux_create_controls(struct asnux_card *acard)
{
	struct snd_kcontrol *kctl;
	int i, err;

	for (i = 0; i < ARRAY_SIZE(asnux_controls); i++) {
		kctl = snd_ctl_new1(&asnux_controls[i], acard);
		if (!kctl)
			return -ENOMEM;
		err = snd_ctl_add(acard->card, kctl);
		if (err < 0) {
			snd_ctl_free_one(kctl);
			return err;
		}
	}

	return 0;
}
