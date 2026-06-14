# ActiveHarnessPricing

LLM model pricing data for Ruby. Fetches and caches pricing from **models.dev** and **OpenRouter**, exposes a unified `ActiveHarness::Pricing` namespace.

Used as a dependency by [active_harness](https://github.com/the-teacher/active_harness), but works standalone too.

## Installation

```ruby
gem "active_harness_pricing"
```

## Usage

```ruby
require "active_harness_pricing"

# Find pricing for a specific model
price = ActiveHarness::Pricing.find("gpt-4o")
# => #<ModelPrice id="gpt-4o" provider="openai" input=$2.5/M output=$10.0/M ctx=128000>

price.input_per_million   # => 2.5
price.output_per_million  # => 10.0
price.context_window      # => 128000
price.categories          # => ["vision"]

# All models
ActiveHarness::Pricing.all              # => Array<ModelPrice>

# By provider
ActiveHarness::Pricing.providers.openai       # => Array<ModelPrice>
ActiveHarness::Pricing.providers["anthropic"] # => Array<ModelPrice>
ActiveHarness::Pricing.providers.list         # => ["anthropic", "azure", "gemini", ...]

# OpenRouter (separate source, covers all OR-routed models)
ActiveHarness::Pricing::OpenRouter.find("openai/gpt-4o")  # => ModelPrice or nil
ActiveHarness::Pricing::OpenRouter.all                    # => Array<ModelPrice>

# Force refresh cache
ActiveHarness::Pricing.update   # refreshes models.dev cache
ActiveHarness::Pricing.preload! # fetches both sources (used at Rails boot)
```

## Data sources

| Source | Coverage | Cache file |
|--------|----------|------------|
| `Pricing::ModelsDev` | All major providers via [models.dev](https://models.dev) | `tmp/active_harness/models_dev_pricing.json` |
| `Pricing::OpenRouter` | All OpenRouter-routed models (text, image, audio, embed, …) | `tmp/active_harness/openrouter_pricing.json` |

Cache TTL is **3 days**. On first access the cache is fetched automatically; network failures are silently ignored and the last cached data is used.

## ModelPrice fields

```ruby
price.id                            # "gpt-4o"
price.name                          # "GPT-4o"
price.provider                      # "openai"
price.input_per_million             # USD per 1M input tokens
price.output_per_million            # USD per 1M output tokens
price.cache_read_input_per_million  # prompt cache read rate
price.cache_write_input_per_million # prompt cache write rate
price.context_window                # max context tokens
price.max_output_tokens             # max output tokens
price.input_modalities              # ["text", "image", ...]
price.output_modalities             # ["text", ...]
price.image_input_per_million       # vision input rate
price.image_output_per_million      # image generation rate
price.audio_input_per_million       # audio input rate
price.audio_output_per_million      # TTS output rate
price.web_search_per_request        # per web-search call in USD
price.categories                    # ["vision", "imggen", "audio", ...]
```

## Filtering providers

By default all providers from `MODELS_DEV_PROVIDER_MAP` are fetched. To restrict:

```ruby
ActiveHarness::Pricing::ModelsDev.available_providers = %w[openai anthropic gemini]
ActiveHarness::Pricing.update  # rebuild cache with the new filter
```

## Rails

`ActiveHarness::Pricing.preload!` is called automatically at boot when used together with `active_harness` (via its Railtie). No extra setup needed.

## License

MIT
