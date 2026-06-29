# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/waseigo/vatchex_vies/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/waseigo/vatchex_vies/releases/tag/v0.1.0
