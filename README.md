# VatchexVies

A client library for the EU VIES REST API (VAT number validation and company information lookup).

Note: this project is a volunteer effort and not in any way affiliated with the European Commission or the VIES service.

## Installation

The package is [available on Hex](https://hex.pm/packages/vatchex_vies) and can be installed
by adding `vatchex_vies` to your list of dependencies in `mix.exs`.

```elixir
def deps do
  [
    {:vatchex_vies, "~> 0.1"},
  ]
end
```

## Usage

```elixir
{:ok, data} = VatchexVies.lookup("EL", "998144460")
```

Returns a map with company information (onomasia, address, country code, VAT validity status, etc.) or `{:error, errors}` with validation/service error details.

Refer to the [documentation on HexDocs](https://hexdocs.pm/vatchex_vies/VatchexVies.html) for the full API reference.

## Error shape

`lookup/3` always returns errors as `{:error, map}` with a consistent shape:

```elixir
{:error, %{code: <atom>, descr: <string>}}
```

| code | descr | meaning |
|------|-------|---------|
| `:invalid_vat` | `"Invalid VAT ID"` | VAT number invalid per VIES |
| `:vies_http_error` | `"HTTP status code 500"` | Non-200 from VIES |
| `:vies_request_failed` | `"Network error: ..."` | Transport failure |
| `:vies_status_unavailable` | `"..."` | Cannot reach VIES status endpoint |

Internal errors use atoms for `:code` and human-readable strings for `:descr`.

## Usage with caching

Optional caching is available via [Cachex](https://hex.pm/packages/cachex) v4.x. Successful lookups are cached for a configurable TTL; errors are never cached.

### Setup

1. Add `cachex` to your dependencies:

```elixir
# mix.exs
{:cachex, "~> 4.1"}
```

2. Start a Cachex instance in your supervision tree:

```elixir
# application.ex
children = [
  {Cachex, name: :vatchex_vies, limit: 10_000},
  ...
]
```

3. Pass the cache adapter to `lookup/3`:

```elixir
VatchexVies.lookup("EL", "998144460", cache: VatchexVies.CachexCache)
```

### Configuration

```elixir
# config/config.exs
config :vatchex_vies, :cache_name, :vatchex_vies  # Cachex cache name (default: :vatchex_vies)
config :vatchex_vies, :cache_ttl, 86_400_000       # TTL in milliseconds (default: 24 hours)
```

### Behavior

- Only successful results (`{:ok, data}`) are cached. Validation failures, HTTP errors, and transport errors always hit the API.
- Cache keys are based on the country code and VAT number.
- If Cachex is not started or not in the dependency list, the `:cache` option is silently ignored.
- You can provide your own cache adapter by implementing the `VatchexVies.Cache` protocol.

## Testing

```sh
mix test
```

11 unit tests, no external dependencies or live service calls. Covers VAT lookup (valid/invalid/transport failure), country availability, and caching behavior.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for the full history.

### v0.1.0

Initial release:

- Client for the EU VIES REST API (VAT number validation and company lookup)
- Optional caching via Cache with configurable TTL
- `Cache` protocol for pluggable cache adapters
- 11 tests with Req.Test stubs (no live service calls)
- Structured error responses with `code`/`descr` convention

## Documentation

The docs can be found at <https://hexdocs.pm/vatchex_vies>.
