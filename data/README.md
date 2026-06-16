# Pricing Data

Three JSON files with LLM model pricing from different sources, all sharing the same format. Updated daily via GitHub Actions.

| File | Source | Models | Notes |
|---|---|---|---|
| `pricepertoken.json` | [pricepertoken.com](https://pricepertoken.com) | ~550 | Includes performance data (TPS, TTFT) |
| `modelsdev.json` | [models.dev](https://models.dev) | ~1600 | Broadest provider coverage |
| `openrouter.json` | [openrouter.ai](https://openrouter.ai) | ~290 | Routing prices via OpenRouter |

---

## Canonical Key

Each entry is keyed by a normalized model name — lowercase, hyphen-separated, no provider prefix:

```
"gpt-4o"
"mistral-nemo"
"claude-3-5-sonnet"
"gemini-2-5-flash"
```

The same key across different files refers to the same model, which allows price comparison between sources.

**How the key is derived** from raw provider model IDs:

```
"mistralai/mistral-nemo"                           → "mistral-nemo"
"global.anthropic.claude-haiku-4-5-20251001-v1:0"  → "claude-haiku-4-5"
"gpt-4o"                                            → "gpt-4o"
"models/gemini-2.5-flash"                          → "gemini-2-5-flash"
"claude-3-5-haiku-20241022"                        → "claude-3-5-haiku"
```

Rules: strip `author/` prefix, remove date/version suffixes (`-20241022`, `-v2:0`), normalize separators to hyphens.

---

## Entry Format

```json
{
  "mistral-nemo": {
    "name":                "Mistral Nemo",
    "input_per_1m":        0.02,
    "output_per_1m":       0.03,
    "context_window":      131072,
    "cache_read_per_1m":   0.005,
    "tokens_per_second":   85.4,
    "time_to_first_token": 0.61
  }
}
```

### Fields

| Field | Type | Description |
|---|---|---|
| `name` | String | Display name of the model |
| `input_per_1m` | Float | Price per 1M input tokens, USD |
| `output_per_1m` | Float | Price per 1M output tokens, USD |
| `context_window` | Integer? | Maximum context length in tokens |
| `cache_read_per_1m` | Float? | Price per 1M cache-read tokens (Anthropic, OpenAI) |
| `tokens_per_second` | Float? | Generation speed — `pricepertoken.json` only |
| `time_to_first_token` | Float? | Time to first token in seconds — `pricepertoken.json` only |

Fields marked `?` are optional and not present for every model.

---

## Multimodality and Per-Token-Type Pricing

Many modern models accept multiple token types, each with its own price.

### Examples

**GPT-4o** accepts text and images:
- Text input tokens: `$2.5/M`
- Image input tokens: billed separately at ~`$1.275/M` (OpenAI counts image tiles by their own scheme)
- Cache-read tokens: `$1.25/M` → stored in `cache_read_per_1m`

**Gemini 2.5 Flash** accepts text, images, audio, and video:
- Text tokens: `$0.09/M` input / `$0.71/M` output
- Audio tokens: `$0.07/M` input (different rate)
- Images and video: separate rates per provider scheme

**Claude** supports prompt caching:
- Standard input tokens: `$3.0/M`
- Cache-read tokens: `$0.3/M` (10× cheaper) → stored in `cache_read_per_1m`
- Cache-write tokens: `$3.75/M` (more expensive; not stored in this format)

### Why only `input_per_1m` for input

The format stores the **text token rate** as the primary input price. This covers ~95% of real-world usage since most LLM requests send text.

Image, audio, and video token rates are **not unified** in this format because each provider uses different billing units (tiles, seconds, pixels). For accurate cost calculation on multimodal requests, consult the provider's API documentation directly.

---

## Price Differences Between Sources

The same model may have different prices across files:

```
gemini-2-5-flash:
  pricepertoken → $0.30/M input   (Google's official rate)
  modelsdev     → $0.09/M input   (different tier or stale data)
  openrouter    → $0.30/M input   (OpenRouter routing price)
```

Common reasons for differences:
- Providers offer multiple pricing tiers (Batch API, volume discounts)
- Sources update at different frequencies and may carry stale data
- OpenRouter adds a small markup over the underlying provider price

`PriceResolver.max_cost` selects the **highest** price across all sources as a conservative cost estimate; `PriceResolver.min_cost` selects the lowest.

---

## Updating Data Manually

```bash
ruby bin/fetch_pricepertoken   # refresh pricepertoken.json
ruby bin/fetch_modelsdev       # refresh modelsdev.json
ruby bin/fetch_openrouter      # refresh openrouter.json
```
