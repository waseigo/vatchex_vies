# VatchexVies — Design Document

## Overview

VatchexVies is an Elixir client library for the EU VIES REST API (VAT number validation and company lookup). It accepts a country code and VAT ID and returns basic company registration data: name, address, and VAT validity status.

The public API is one function: `lookup/3` (returns `{:ok, map}` / `{:error, reason}`). The optional `available_countries/0` and `available?/1` functions check VIES service availability per country.

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

1. Check cache (if `:cache` option provided) -> return cached result on hit
2. POST to VIES REST API with `countryCode` and `vatNumber`
3. Parse response: `valid: true` -> extract name/address, `valid: false` -> `:invalid_vat`
4. Store result in cache (if cache enabled)

### Response map (on success)

```elixir
%{
  country_code: "EL",
  afm: "998144460",
  onomasia: "Company Name",
  commer_title: nil,
  address: "Street Address",
  source: :vies
}
```

### Error shape

```
{:error, %{code: atom, descr: string}}
```

| code                       | descr                    | meaning                           |
| -------------------------- | ------------------------ | --------------------------------- |
| `:invalid_vat`             | `"..."`                  | VAT number invalid per VIES       |
| `:vies_http_error`         | `"HTTP status code 500"` | Non-200 from VIES                 |
| `:vies_request_failed`     | `"Network error: ..."`   | Transport failure                 |
| `:vies_status_unavailable` | `"..."`                  | Cannot reach VIES status endpoint |

### Caching

Caching is implemented via the `VatchexVies.Cache` protocol, allowing pluggable adapters. The built-in `VatchexVies.CachexCache` adapter wraps Cachex v4.x and is conditionally compiled -- it is only available when Cachex is loaded at runtime.

Key properties:

- Only successful results are cached. Errors always bypass the cache.
- Cache key: `"vies:{country_code}:{tin}"`
- Default TTL: 24 hours (configurable via `:cache_ttl` option)
- Zero impact when not used: no extra dependencies, no application config required.

## Module Responsibilities

### `VatchexVies` (public surface)

- `lookup/3` -- main entry point, checks delegates to API
- `available_countries/0` -- fetches VIES service availability per country
- `available?/1` -- convenience wrapper for single country

### `VatchexVies` (internal)

- `do_lookup/3` -- performs the REST API call, parses response

### `VatchexVies.Cache` (protocol)

- `get/2` -- cache lookup
- `put/3` -- cache store

### `VatchexVies.CachexCache` (adapter)

- Wraps Cachex v4.x for use as cache adapter
- Conditionally compiled (only when Cachex is available)

## Request Flow

```
Input:  country_code: "EL", tin: "998144460"

Step 1 — Cache check
  ├─ cache hit? -> return cached result
  └─ cache miss -> continue

Step 2 — API call
  ├─ POST to ec.europa.eu/taxation_customs/vies/rest-api/check-vat-number
  ├─ HTTP 200, valid: true  -> {:ok, %{onomasia, address, afm, country_code, source: :vies}}
  ├─ HTTP 200, valid: false -> {:error, %{code: :invalid_vat, descr: "..."}}
  ├─ HTTP non-200           -> {:error, %{code: :vies_http_error, descr: "..."}}
  └─ Transport failure      -> {:error, %{code: :vies_request_failed, descr: "..."}}

Step 3 — Cache store (if cache enabled and result is {:ok, ...})
```

## Dependencies

| Dependency          | Purpose                                         |
| ------------------- | ----------------------------------------------- |
| `req`               | HTTP client for VIES REST API calls             |
| `plug`              | Req.Test support for testing                    |
| `jason`             | JSON encoding for test stubs                    |
| `cachex` (optional) | In-memory caching via `VatchexVies.CachexCache` |

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

11 tests, no external dependencies or live service calls. Covers VAT lookup (valid/invalid/transport failure), country availability, and CachexCache adapter behavior.

## Usage as VatchexGreece fallback

VatchexVies is designed to be used standalone or as an optional fallback for VatchexGreece. When VatchexGreece's primary GSIS lookup fails, it can call `VatchexVies.lookup("EL", normalized_afm)` to retrieve basic company name and address from the EU VIES API.

The response map includes `source: :vies` so callers can distinguish the data origin.
