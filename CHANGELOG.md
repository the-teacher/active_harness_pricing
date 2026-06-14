# Changelog

## [0.1.3] - 2026-06-15

### Changed
- `Pricing` facade trimmed: removed `update`, `reload!`, `cache_file`, `available_providers` — these are `ModelsDev` implementation details, not public API; `find`, `all`, `providers`, `for_provider`, `provider_names`, `preload!` remain
- Facade comment updated to explain why `ModelsDev` is the default general source and when `OpenRouter` is consulted separately

### Fixed
- Corrected stale "24h cache" comments in `pricing.rb` and `models_dev.rb` — TTL has always been 72h (`3 * 86_400`), only the comments were wrong

## [0.1.2] - 2026-06-15

### Fixed
- `load_registry` now rescues `StandardError` instead of only `JSON::ParserError` — prevents crash on `Errno::ENOENT` / `Errno::EACCES` (race condition or permission error on the cache file); affects both `ModelsDev` and `OpenRouter`; fixes uncaught exception in `preload!` `ensure` block during Rails boot when the cache file is inaccessible

## [0.1.1] - 2026-06-14

### Fixed
- Replace `filter_map` with `map.compact` for Ruby 2.6 compatibility (`models_dev.rb`, `openrouter.rb`)

## [0.1.0] - 2026-06-14

### Added
- Initial release — extracted from `active_harness` gem as a standalone dependency
- `ActiveHarness::Pricing::ModelsDev` — fetches and caches model pricing from [models.dev](https://models.dev) (732 models across 12 providers)
- `ActiveHarness::Pricing::OpenRouter` — fetches and caches model pricing from OpenRouter API across all modalities: text, image, audio, embeddings, speech, transcription, video, rerank (425 models)
- `ActiveHarness::Pricing` facade — delegates to `ModelsDev` with `find`, `all`, `providers`, `update`, `preload!`, `reload!`
- `ModelPrice` struct with full modality-specific pricing fields: text, image, audio, cache, web search
- `ProvidersProxy` — access providers as methods (`Pricing.providers.openai`) or via `[]`
- 3-day in-memory and file cache with automatic refresh on stale data
- `ModelsDev.available_providers=` — configurable provider filter
- `make get` — fetch and cache data from both sources locally
- Rails compatibility: `preload!` integrates with `active_harness` Railtie
- Ruby 2.6+ compatibility
