# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-06-29

### Added

- `address_collapsed` field — newlines collapsed into spaces for single-line display
- `commer_title` field — now extracts `tradingName` from VIES response
- HTTP 429 rate-limit handling — `:vies_too_many_requests` error code
- Empty/whitespace-only VAT validation — returns immediately with no API call
- `config/config.exs` with documented defaults for cache name and TTL
- Cache protocol `put/4` now accepts `:ttl` option, falls back to app config

### Changed

- Error shape unified to `{:error, %{code: atom, descr: string}}` everywhere
- `:plug` option renamed to `:test_adapter` to avoid confusion with Req.Step plugs
- `address` now preserves the raw VIES value (may contain newlines)
- Cachex is now a true optional dependency — removed from runtime deps
- Test coverage threshold raised to 80%
- All source files updated to SPDX 2026
- Removed `@spec` annotations

### Fixed

- Req retry disabled when using test adapter — test suite now runs in 0.2s
- `cache_store` now stores only the data map (not `{:ok, data}` tuple) — fixes double-wrapping on cache hit
- Null `name`/`address` from VIES no longer crashes `process_name`/`process_address`

## [0.1.0] - 2026-01-25

### Added

- Client for the EU VIES REST API (VAT number validation and company lookup)
- `VatchexVies.lookup/3` with support for country code, VAT ID, and optional caching
- `VatchexVies.available_countries/0` and `VatchexVies.available?/1` for checking VIES service availability per country
- `VatchexVies.Cache` protocol for pluggable cache adapters
- `VatchexVies.CachexCache` adapter for Cachex v4.x (conditionally compiled when Cachex is available)
- Structured error responses: `{:error, %{code: atom, descr: string}}`
- 11 unit tests with Req.Test stubs (no live service calls)
- DESIGN.md architecture document

[Unreleased]: https://github.com/waseigo/vatchex_vies/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/waseigo/vatchex_vies/releases/tag/v1.0.0
[0.1.0]: https://github.com/waseigo/vatchex_vies/releases/tag/v0.1.0
