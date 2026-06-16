#include "asnux_main.h"

int asnux_buffer_size = ASNUX_DEFAULT_BUFFER_SIZE;
int asnux_sample_rate = ASNUX_DEFAULT_SAMPLE_RATE;
int asnux_channels = ASNUX_DEFAULT_CHANNELS;
int asnux_periods = ASNUX_DEFAULT_PERIODS;

module_param_named(buffer_size, asnux_buffer_size, int, 0644);
module_param_named(sample_rate, asnux_sample_rate, int, 0644);
module_param_named(channels, asnux_channels, int, 0644);
module_param_named(periods, asnux_periods, int, 0644);

MODULE_PARM_DESC(buffer_size, "Buffer size in frames (16-8192)");
MODULE_PARM_DESC(sample_rate, "Sample rate in Hz (8000-192000)");
MODULE_PARM_DESC(channels, "Number of channels (1-8)");
MODULE_PARM_DESC(periods, "Number of periods (2-1024)");

static struct asnux_card *asnux_cards[ASNUX_MAX_CARDS];
static int asnux_cards_created;

MODULE_AUTHOR("ASNUX Team <team@devfrp.io>");
MODULE_DESCRIPTION("ASNUX - Audio Streams NUX: Low-latency virtual ALSA driver for Linux");
MODULE_LICENSE("GPL v2");
MODULE_VERSION(DRIVER_VERSION);
MODULE_SOFTDEP("pre: snd-pcm snd");

static int asnux_pcm_new(struct asnux_card *acard)
{
	struct snd_pcm *pcm;
	int err;

	err = snd_pcm_new(acard->card, DRIVER_NAME, 0, 1, 1, &pcm);
	if (err < 0)
		return err;

	pcm->private_data = acard;
	strncpy(pcm->name, "ASNUX Low-Latency Audio Engine", sizeof(pcm->name));

	snd_pcm_set_ops(pcm, SNDRV_PCM_STREAM_PLAYBACK, &asnux_pcm_ops);
	snd_pcm_set_ops(pcm, SNDRV_PCM_STREAM_CAPTURE, &asnux_pcm_ops);

	acard->pcm = pcm;

	return 0;
}

static int asnux_probe(struct platform_device *pdev)
{
	struct asnux_card *acard;
	struct snd_card *card;
	int err;

	if (asnux_cards_created >= ASNUX_MAX_CARDS)
		return -ENODEV;

	err = snd_card_new(&pdev->dev, -1, NULL, THIS_MODULE,
			   sizeof(struct asnux_card), &card);
	if (err < 0)
		return err;

	acard = card->private_data;
	acard->card = card;
	acard->index = asnux_cards_created;
	acard->buffer_size = asnux_buffer_size;
	acard->sample_rate = asnux_sample_rate;
	acard->channels = asnux_channels;
	acard->periods = asnux_periods;
	acard->period_size = asnux_buffer_size / asnux_periods;
	mutex_init(&acard->lock);

	strncpy(card->driver, DRIVER_NAME, sizeof(card->driver));
	strncpy(card->shortname, "ASNUX Audio Engine", sizeof(card->shortname));
	strncpy(card->longname, "ASNUX Low-Latency Virtual Audio Device", sizeof(card->longname));
	strncpy(card->mixername, "ASNUX Mixer", sizeof(card->mixername));

	err = asnux_pcm_new(acard);
	if (err < 0) {
		snd_card_free(card);
		return err;
	}

	err = asnux_create_controls(acard);
	if (err < 0) {
		snd_card_free(card);
		return err;
	}

	err = snd_card_register(card);
	if (err < 0) {
		snd_card_free(card);
		return err;
	}

	asnux_cards[asnux_cards_created] = acard;
	asnux_cards_created++;
	platform_set_drvdata(pdev, card);

	dev_info(&pdev->dev,
		 "ASNUX registered: card #%d, buffer=%d frames, rate=%d Hz, channels=%d\n",
		 acard->index, acard->buffer_size, acard->sample_rate, acard->channels);

	return 0;
}

static void asnux_remove(struct platform_device *pdev)
{
	struct snd_card *card = platform_get_drvdata(pdev);
	int i;

	if (card) {
		dev_info(&pdev->dev, "ASNUX card removed\n");

		for (i = 0; i < ASNUX_MAX_CARDS; i++) {
			if (asnux_cards[i] && asnux_cards[i]->card == card) {
				asnux_cards[i] = NULL;
				asnux_cards_created = max(0, asnux_cards_created - 1);
				break;
			}
		}

		snd_card_free(card);
	}
}

static struct platform_driver asnux_driver = {
	.driver = {
		.name = DRIVER_NAME,
	},
	.probe = asnux_probe,
	.remove = asnux_remove,
};

static struct platform_device *asnux_pdev;

static int __init asnux_init(void)
{
	int err;

	BUILD_BUG_ON(ASNUX_MIN_BUFFER_SIZE < 16);
	BUILD_BUG_ON(ASNUX_MAX_BUFFER_SIZE > 8192);

	asnux_buffer_size = clamp_t(int, asnux_buffer_size,
				    ASNUX_MIN_BUFFER_SIZE, ASNUX_MAX_BUFFER_SIZE);
	asnux_sample_rate = clamp_t(int, asnux_sample_rate,
				    ASNUX_MIN_SAMPLE_RATE, ASNUX_MAX_SAMPLE_RATE);
	asnux_channels = clamp_t(int, asnux_channels, 1, ASNUX_MAX_CHANNELS);
	asnux_periods = clamp_t(int, asnux_periods,
				ASNUX_MIN_PERIODS, ASNUX_MAX_PERIODS);

	err = platform_driver_register(&asnux_driver);
	if (err < 0)
		return err;

	asnux_pdev = platform_device_register_simple(DRIVER_NAME, -1, NULL, 0);
	if (IS_ERR(asnux_pdev)) {
		platform_driver_unregister(&asnux_driver);
		return PTR_ERR(asnux_pdev);
	}

	pr_info("ASNUX v%s loaded: buffer=%d, rate=%d, channels=%d, periods=%d\n",
		DRIVER_VERSION, asnux_buffer_size, asnux_sample_rate,
		asnux_channels, asnux_periods);

	return 0;
}

static void __exit asnux_exit(void)
{
	platform_device_unregister(asnux_pdev);
	platform_driver_unregister(&asnux_driver);
	pr_info("ASNUX unloaded\n");
}

module_init(asnux_init);
module_exit(asnux_exit);
