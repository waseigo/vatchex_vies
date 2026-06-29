# VatchexVies — Design Document

## Overview

VatchexVies is an Elixir client library for the EU VIES REST API (VAT number validation and company lookup). It accepts a country code and VAT ID and returns basic company registration data: name, address, and VAT validity status.

The public API is one function: `lookup/3` (returns `{:ok, map}` / `{:error, %{code:, descr:}}`). The optional `available_countries/0` and `available?/1` functions check VIES service availability per country.

## Architecture

```
┌───────────────────────────────┐
│         Public API            │
│  lookup/3 → cache? → do_lookup│
│  available_countries/0        │
│  available?/1                 │
└──────────────┬────────────────┘
               │
       ┌───────┴───────┐
       ▼               ▼
  ┌──────────┐  ┌───────────────┐
  │do_lookup │  │status endpoint│
  │ Req.post │  │   Req.get     │
  └──────────┘  └───────────────┘
```

### The `lookup/3` function

1. Trim input; reject empty/whitespace-only VAT numbers immediately
2. Check cache (if `:cache` option provided) → return cached result on hit
3. POST to VIES REST API with `countryCode` and `vatNumber`
4. Parse response:
   - `valid: true` → extract name/tradingName/address, collapse address for display
   - `valid: false` → `:invalid_vat`
   - HTTP 429 → `:vies_too_many_requests`
   - Other non-2xx → `:vies_http_error`
5. Store result in cache (if cache enabled, successful results only)

### Response map (on success)

```elixir
%{
  country_code: "EL",
  afm: "998144460",
  onomasia: "Company Name",
  commer_title: "Trading Name",
  address: "Street Address\nPostCode City",
  address_collapsed: "Street Address PostCode City",
  source: :vies
}
```

### Error shape

```
{:error, %{code: atom, descr: string}}
```

| code                       | descr                    | meaning                           |
| -------------------------- | ------------------------ | --------------------------------- |
| `:invalid_vat`             | `"Invalid VAT number"`   | VAT number invalid per VIES       |
| `:invalid_vat`             | `"VAT number is blank"`  | Empty/whitespace-only input       |
| `:vies_http_error`         | `"HTTP 500"`             | Non-2xx from VIES                 |
| `:vies_too_many_requests`  | `"Rate limited by VIES"` | HTTP 429 — caller should back off |
| `:vies_request_failed`     | `"connection refused"`   | Transport failure                 |
| `:vies_status_unavailable` | `"..."`                  | Cannot reach VIES status endpoint |

### Caching

Caching is implemented via the `VatchexVies.Cache` protocol, allowing pluggable adapters. The built-in `VatchexVies.CachexCache` adapter wraps Cachex v4.x and is conditionally compiled — it is only available when Cachex is loaded at runtime.

Cachex is **not a hard dependency**. It is only fetched and compiled when the consumer adds it to their own `mix.exs`.

Key properties:

- Only successful results are cached. Errors always bypass the cache.
- Cache key: `"vies:{country_code}:{tin}"`
- Default TTL: 24 hours (configurable via `:cache_ttl` config or `:ttl` option)
- Zero impact when not used: no extra dependencies, no application config required.

## Module Responsibilities

### `VatchexVies` (public surface)

- `lookup/3` — main entry point, validates input, checks cache, delegates to API
- `available_countries/0` — fetches VIES service availability per country
- `available?/1` — convenience wrapper for single country

### `VatchexVies` (internal)

- `do_lookup/3` — performs the REST API call, parses response
- `process_name/1`, `process_address/1` — normalise whitespace
- `request_error_description/1` — convert transport errors to readable strings
- `maybe_attach_adapter/2` — inject Req.Test adapter when testing

### `VatchexVies.Cache` (protocol)

- `get/2` — cache lookup
- `put/4` — cache store (accepts `ttl` option)

### `VatchexVies.CachexCache` (adapter)

- Wraps Cachex v4.x for use as cache adapter
- Conditionally compiled (only when Cachex is available)
- Reads `:cache_name` and `:cache_ttl` from application config

## Request Flow

```
Input:  country_code: "EL", tin: "998144460"

Step 0 — Input validation
  └─ trim whitespace; reject blank input immediately

Step 1 — Cache check
  ├─ cache hit? -> return cached result
  └─ cache miss -> continue

Step 2 — API call
  ├─ POST to ec.europa.eu/taxation_customs/vies/rest-api/check-vat-number
  ├─ HTTP 200, valid: true  -> {:ok, %{onomasia, commer_title, address, address_collapsed, afm, country_code, source: :vies}}
  ├─ HTTP 200, valid: false -> {:error, %{code: :invalid_vat, descr: "Invalid VAT number"}}
  ├─ HTTP 429               -> {:error, %{code: :vies_too_many_requests, descr: "Rate limited by VIES"}}
  ├─ HTTP non-2xx           -> {:error, %{code: :vies_http_error, descr: "HTTP #{status}"}}
  └─ Transport failure      -> {:error, %{code: :vies_request_failed, descr: "..."}}

Step 3 — Cache store (if cache enabled and result is {:ok, ...})
```

## Dependencies

| Dependency | Purpose | Required |
|---|---|---|
| `req` | HTTP client for VIES REST API calls | Yes |
| `jason` | JSON encoding (used in tests) | Yes |
| `cachex` | In-memory caching via `VatchexVies.CachexCache` | No (add to your deps) |
| `plug` | Req.Test support for testing | Dev/Test only |

## Configuration

None required. Configure via `lookup/3` options or application config:

```elixir
VatchexVies.lookup("EL", "99814",
  cache: VatchexVies.CachexCache
)
```

## Testing

```
mix test
```

21 tests, no external dependencies or live service calls. Covers VAT lookup (valid/invalid/transport failure/429/blank input), country availability, CachexCache adapter, protocol edge cases, and nil-field handling.

## Usage as VatchexGreece fallback

VatchexVies is designed to be used standalone or as an optional fallback for VatchexGreece. When VatchexGreece's primary GSIS lookup fails, it can call `VatchexVies.lookup("EL", normalized_afm)` to retrieve basic company name and address from the EU VIES API.

The response map includes `source: :vies` so callers can distinguish the data origin.
