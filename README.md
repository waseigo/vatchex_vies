# VatchexVies

A client library for the EU VIES REST API (VAT number validation and company information lookup).

Note: this project is a volunteer effort and not in any way affiliated with the European Commission or the VIES service.

## Installation

The package is [available on Hex](https://hex.pm/packages/vatchex_vies) and can be installed
by adding `vatchex_vies` to your list of dependencies in `mix.exs`.

```elixir
def deps do
  [
    {:vatchex_vies, "~> 1.0"}
  ]
end
```

## Usage

```elixir
{:ok, data} = VatchexVies.lookup("EL", "998144460")
```

Returns a map with company information or `{:error, %{code: atom, descr: string}}` with error details.

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

- `address` — the raw address as returned by VIES (may contain newlines)
- `address_collapsed` — newlines collapsed into spaces for single-line display
- `commer_title` — the trading name, or `nil` if VIES did not return one

## Error shape

`lookup/3` always returns errors as `{:error, %{code: atom, descr: string}}`:

```elixir
{:error, %{code: :invalid_vat, descr: "Invalid VAT number"}}
```

| code                       | descr                                | meaning                                   |
| -------------------------- | ------------------------------------ | ----------------------------------------- |
| `:invalid_vat`             | `"Invalid VAT number"`               | VAT number invalid per VIES               |
| `:invalid_vat`             | `"VAT number is blank"`              | Empty/whitespace-only input (no API call) |
| `:vies_http_error`         | `"HTTP 500"`                         | Non-2xx from VIES                         |
| `:vies_too_many_requests`  | `"Rate limited by VIES"`             | HTTP 429 — caller should back off         |
| `:vies_request_failed`     | `"connection refused"`               | Transport failure                         |
| `:vies_status_unavailable` | `"VIES status endpoint unavailable"` | Cannot reach VIES status endpoint         |

## Usage with caching

Optional caching is available via [Cachex](https://hex.pm/packages/cachex) v4.x. Successful lookups are cached for a configurable TTL; errors are never cached.

**Cachex is not a hard dependency** — you only fetch and compile it if you want caching.

### Setup

1. Add `cachex` to **your** dependencies:

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
config :vatchex_vies, :cache_name, :vatchex_vies   # Cachex cache name (default: :vatchex_vies)
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

21 unit tests, no external dependencies or live service calls. Covers VAT lookup (valid/invalid/transport failure/429/blank input), country availability, cache hit/miss, protocol edge cases, and nil-field handling.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for the full history.

## Support

If this library saves you time or helps your project, consider saying thanks by purchasing a copy of [**Northwind Elixir Traders**](https://leanpub.com/northwind-elixir-traders), an exploratory-learning book that teaches Elixir, Ecto, and SQLite all in one hands-on project, with its [source code](https://github.com/waseigo/northwind_elixir_traders) released under the Apache-2.0 License.

<a href="https://leanpub.com/northwind-elixir-traders">
  <img src="https://raw.githubusercontent.com/waseigo/northwind_elixir_traders/main/etc/northwind-elixir-traders-cover.jpg"
       width="200"
       alt="Northwind Elixir Traders cover">
</a>

See what readers are saying on the [book's ElixirForum thread](https://elixirforum.com/t/northwind-elixir-traders-pragprog/70887).

## Documentation

The docs can be found at <https://hexdocs.pm/vatchex_vies>.
