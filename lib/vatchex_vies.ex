# SPDX-FileCopyrightText: 2026 Isaak Tsalicoglou <isaak@waseigo.com>
# SPDX-License-Identifier: Apache-2.0

defmodule VatchexVies do
  @moduledoc """
  Client for the EU VIES REST API (VAT number validation and company lookup).

  ## Public API

  ```elixir
  VatchexVies.lookup("EL", "998144460")
  VatchexVies.lookup("EL", "998144460", cache: VatchexVies.CachexCache)
  ```

  Returns `{:ok, map}` with company data or `{:error, %{code: atom, descr: string}}`.

  ## Response map (on success)

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

  ## Error codes

  | code | descr | meaning |
  |------|-------|---------|
  | `:invalid_vat` | `"Invalid VAT number"` | VAT number invalid per VIES |
  | `:invalid_vat` | `"VAT number is blank"` | Empty or whitespace-only input (no API call) |
  | `:vies_http_error` | `"HTTP 500"` | Non-2xx from VIES |
  | `:vies_too_many_requests` | `"Rate limited by VIES"` | HTTP 429 — caller should back off |
  | `:vies_request_failed` | `"connection refused"` | Transport failure |
  | `:vies_status_unavailable` | `"VIES status endpoint unavailable"` | Cannot reach VIES status endpoint |
  """

  @vies_check_url "https://ec.europa.eu/taxation_customs/vies/rest-api/check-vat-number"
  @vies_status_url "https://ec.europa.eu/taxation_customs/vies/rest-api/check-status"

  @doc """
  Looks up a VAT number via the EU VIES API.

  ## Options

  - `:cache` — a module implementing `VatchexVies.Cache` protocol (e.g. `VatchexVies.CachexCache`)
  - `:test_adapter` — a `{Req.Test, module}` tuple for test stubbing
  """
  def lookup(country_code, tin, opts \\ []) do
    tin = String.trim(tin)

    if tin == "" do
      {:error, %{code: :invalid_vat, descr: "VAT number is blank"}}
    else
      cache = Keyword.get(opts, :cache, nil)
      cache_key = "vies:#{country_code}:#{tin}"

      case cache_get(cache, cache_key) do
        {:ok, data} ->
          {:ok, data}

        :miss ->
          result = do_lookup(country_code, tin, opts)
          cache_store(cache, cache_key, result)
          result
      end
    end
  end

  @doc """
  Checks if VIES is available for the given country code.
  Returns `{:ok, boolean()}` or `{:error, %{code: atom, descr: string}}`.

  ## Options

  - `:test_adapter` — a `{Req.Test, module}` tuple for test stubbing
  """
  def available?(country_code, opts \\ []) do
    case available_countries(opts) do
      {:ok, countries} -> {:ok, Map.get(countries, country_code, false)}
      error -> error
    end
  end

  @doc """
  Returns a map of country codes to VIES availability (true/false).

  ## Options

  - `:test_adapter` — a `{Req.Test, module}` tuple for test stubbing
  """
  def available_countries(opts \\ []) do
    req_opts = [decode_json: [keys: :atoms], receive_timeout: 10_000]
    req_opts = maybe_attach_adapter(req_opts, Keyword.get(opts, :test_adapter))

    case Req.get(@vies_status_url, req_opts) do
      {:ok, %Req.Response{status: 200, body: %{countries: countries}}} when is_list(countries) ->
        map = Map.new(countries, &{&1.countryCode, &1.availability == "Available"})
        {:ok, map}

      _ ->
        {:error, %{code: :vies_status_unavailable, descr: "VIES status endpoint unavailable"}}
    end
  end

  # --- Private ---

  defp do_lookup(country_code, tin, opts) do
    json = %{countryCode: country_code, vatNumber: tin}

    req_opts = [json: json, decode_json: [keys: :atoms], receive_timeout: 15_000]
    req_opts = maybe_attach_adapter(req_opts, Keyword.get(opts, :test_adapter))

    case Req.post(@vies_check_url, req_opts) do
      {:ok, %Req.Response{body: %{valid: true} = body}} ->
        result = %{
          country_code: Map.get(body, :countryCode, country_code),
          afm: Map.get(body, :vatNumber, tin),
          onomasia: (Map.get(body, :name) || "") |> process_name(),
          commer_title: Map.get(body, :tradingName),
          address: Map.get(body, :address) || "",
          address_collapsed: (Map.get(body, :address) || "") |> process_address(),
          source: :vies
        }

        {:ok, result}

      {:ok, %Req.Response{body: %{valid: false}}} ->
        {:error, %{code: :invalid_vat, descr: "Invalid VAT number"}}

      {:ok, %Req.Response{status: 429}} ->
        {:error, %{code: :vies_too_many_requests, descr: "Rate limited by VIES"}}

      {:ok, %Req.Response{status: status}} ->
        {:error, %{code: :vies_http_error, descr: "HTTP #{status}"}}

      {:error, reason} ->
        {:error, %{code: :vies_request_failed, descr: Exception.message(reason)}}
    end
  end

  defp process_name(""), do: ""

  defp process_name(name) do
    name
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp process_address(""), do: ""

  defp process_address(address) do
    address
    |> String.replace("\n", " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  # --- Test adapter ---

  defp maybe_attach_adapter(req_opts, nil), do: req_opts

  defp maybe_attach_adapter(req_opts, {Req.Test, _module} = adapter) do
    req_opts |> Keyword.put(:plug, adapter) |> Keyword.put(:retry, false)
  end

  # --- Caching ---

  defp cache_get(nil, _key), do: :miss
  defp cache_get(cache, key), do: VatchexVies.Cache.get(cache, key)

  defp cache_store(_cache, _key, {:error, _}), do: :ok
  defp cache_store(nil, _key, _result), do: :ok

  defp cache_store(cache, key, {:ok, data}) do
    VatchexVies.Cache.put(cache, key, data, [])
  end
end
