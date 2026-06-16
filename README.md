# ActiveHarnessPricing

LLM model pricing data for Ruby. Bundles pricing from three sources — **pricepertoken.com**, **models.dev**, and **OpenRouter** — as JSON files updated daily via GitHub Actions. No network calls at runtime.

Used as a dependency by [active_harness](https://github.com/the-teacher/active_harness), but works standalone too.

## Installation

```ruby
gem "active_harness_pricing"
```

## Data Files

Three bundled files in `data/`, all sharing the same format:

| File | Source | Models | Notes |
|---|---|---|---|
| `data/pricepertoken.json` | [pricepertoken.com](https://pricepertoken.com) | ~550 | Includes TPS and TTFT performance data |
| `data/modelsdev.json` | [models.dev](https://models.dev) | ~1600 | Broadest provider coverage |
| `data/openrouter.json` | [openrouter.ai](https://openrouter.ai) | ~290 | Routing prices via OpenRouter |

See [`data/README.md`](data/README.md) for the full format specification.

## Primary API — PriceResolver

The main entry point. Queries all three bundled sources by canonical model key and returns pricing from each.

```ruby
require "active_harness_pricing"

PR = ActiveHarness::Pricing::PriceResolver

# Pricing from all sources at once
PR.resolve("mistralai/mistral-nemo")
# => {
#   modelsdev:  #<PricingData source=modelsdev  key="mistral-nemo" in=$0.02/M out=$0.04/M>,
#   openrouter: #<PricingData source=openrouter key="mistral-nemo" in=$0.02/M out=$0.03/M>
# }

# Cost from each source (USD)
PR.costs(model_id: "mistralai/mistral-nemo", tokens_input: 10_000, tokens_output: 2_000)
# => { modelsdev: 0.000280, openrouter: 0.000260 }

# Highest cost across sources — conservative upper bound
PR.max_cost(model_id: "mistralai/mistral-nemo", tokens_input: 10_000, tokens_output: 2_000)
# => { cost: 0.000280, source: :modelsdev, all: { modelsdev: 0.000280, openrouter: 0.000260 } }

# Lowest cost across sources — optimistic lower bound
PR.min_cost(model_id: "mistralai/mistral-nemo", tokens_input: 10_000, tokens_output: 2_000)
# => { cost: 0.000260, source: :openrouter, all: { modelsdev: 0.000280, openrouter: 0.000260 } }

# When provider_cost is given it takes priority over all lookups (in both max and min)
PR.max_cost(model_id: "gpt-4o", tokens_input: 10_000, tokens_output: 2_000, provider_cost: 0.001234)
# => { cost: 0.001234, source: :provider, all: { provider: 0.001234 } }
```

### Usage with ActiveHarness agent results

Pass a result or agent object directly — all fields are extracted automatically:

```ruby
result = MyAgent.call(input: "...")

# Short form — pass result or agent object directly
cost = ActiveHarness::Pricing::PriceResolver.max_cost(result)
cost = ActiveHarness::Pricing::PriceResolver.max_cost(agent)

# Equivalent explicit form
cost = ActiveHarness::Pricing::PriceResolver.max_cost(
  model_id:      result.model.name,
  tokens_input:  result.usage.tokens.input,
  tokens_output: result.usage.tokens.output,
  provider_cost: result.usage.cost.total
)

cost&.dig(:cost)    # => 0.000280  (USD)
cost&.dig(:source)  # => :modelsdev
```

`costs` and `min_cost` accept the same short form.

Resolved results are **cached in memory** (TTL: 24 h). In production, only a handful of models are typically used — the first call per model pays the lookup cost; every subsequent call returns from cache instantly. Call `PriceResolver.clear_cache!` to reset manually.

## Normalizer

Converts any raw provider model ID to the canonical lookup key used in the data files.

```ruby
N = ActiveHarness::Pricing::Normalizer

N.to_key("mistralai/mistral-nemo")                           # => "mistral-nemo"
N.to_key("gpt-4o")                                           # => "gpt-4o"
N.to_key("claude-3-5-haiku-20241022")                        # => "claude-3-5-haiku"
N.to_key("global.anthropic.claude-haiku-4-5-20251001-v1:0") # => "claude-haiku-4-5"
N.to_key("models/gemini-2.5-flash")                          # => "gemini-2-5-flash"
```

Rules: strip `author/` prefix, remove date/version suffixes (`-20241022`, `-v2:0`), normalize separators.

## Source

Reads a single data file. Useful when you want to query one specific source.

```ruby
src = ActiveHarness::Pricing::Source.new("data/openrouter.json", :openrouter)

src.find("mistral-nemo")   # exact match   → PricingData or nil
src.find("mistral-nemo-instruct-2407")  # prefix fallback → same PricingData
src.all                    # → Array<PricingData>
```

`PricingData` fields: `key`, `name`, `source`, `input_per_1m`, `output_per_1m`, `context_window`, `cache_read_per_1m`, `tokens_per_second`, `time_to_first_token`.

## Legacy API

The original live-fetch modules are still available for cases that require real-time data:

```ruby
# models.dev — fetches on first access, caches for 3 days in tmp/
ActiveHarness::Pricing.find("gpt-4o")          # => ModelPrice or nil
ActiveHarness::Pricing.all                      # => Array<ModelPrice>
ActiveHarness::Pricing.providers.openai         # => Array<ModelPrice>
ActiveHarness::Pricing.update                   # force refresh

# OpenRouter — fetches all modalities (text, image, audio, embed, …)
ActiveHarness::Pricing::OpenRouter.find("openai/gpt-4o")  # => ModelPrice or nil
ActiveHarness::Pricing::OpenRouter.all                    # => Array<ModelPrice>
ActiveHarness::Pricing::OpenRouter.update                 # force refresh
```

## Updating Bundled Data

The data files are refreshed automatically every day at 06:00 UTC via GitHub Actions. To update locally:

```bash
ruby bin/fetch_pricepertoken   # refresh data/pricepertoken.json
ruby bin/fetch_modelsdev       # refresh data/modelsdev.json
ruby bin/fetch_openrouter      # refresh data/openrouter.json
```

## Adding a New Source

1. Write `bin/fetch_<source>` — fetches data, normalizes names with `Normalizer.to_key`, writes to `data/<source>.json`
2. Add a step to `.github/workflows/update_pricing_data.yml`
3. Add one line to `PriceResolver::SOURCES` in `lib/active_harness/pricing/price_resolver.rb`

## Rails

`ActiveHarness::Pricing.preload!` is called automatically at boot when used together with `active_harness` (via its Railtie). No extra setup needed.

## License

MIT
