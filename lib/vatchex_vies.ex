# SPDX-FileCopyrightText: 2024 Isaak Tsalicoglou <isaak@waseigo.com>
# SPDX-License-Identifier: Apache-2.0

defmodule VatchexVies do
  @moduledoc """
  Client for the EU VIES REST API (VAT number validation and company lookup).

  ## Public API

  ```elixir
  VatchexVies.lookup("EL", "998144460")
  VatchexVies.lookup("EL", "998144460", cache: VatchexVies.CachexCache)
  ```

  Returns `{:ok, map}` with company data or `{:error, reason}`.

  ## Response map (on success)

  ```elixir
  %{
    country_code: "EL",
    afm: "998144460",
    onomasia: "Company Name",
    commer_title: "Trading Name",
    address: "Street Address",
    source: :vies
  }
  ```

  """

  @vies_check_url "https://ec.europa.eu/taxation_customs/vies/rest-api/check-vat-number"
  @vies_status_url "https://ec.europa.eu/taxation_customs/vies/rest-api/check-status"

  @doc """
  Looks up a VAT number via the EU VIES API.

  ## Options

  - `:cache` — a module implementing `VatchexVies.Cache` protocol (e.g. `VatchexVies.CachexCache`)
  - `:plug` — a custom Req plug for testing
  """
  @spec lookup(String.t(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def lookup(country_code, tin, opts \\ []) do
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

  @doc """
  Checks if VIES is available for the given country code.
  Returns `{:ok, boolean()}` or `{:error, reason}`.

  ## Options

  - `:plug` — a custom Req plug for testing
  """
  @spec available?(String.t(), keyword()) :: {:ok, boolean()} | {:error, term()}
  def available?(country_code, opts \\ []) do
    case available_countries(opts) do
      {:ok, countries} -> {:ok, Map.get(countries, country_code, false)}
      error -> error
    end
  end

  @doc """
  Returns a map of country codes to VIES availability (true/false).

  ## Options

  - `:plug` — a custom Req plug for testing
  """
  @spec available_countries(keyword()) :: {:ok, map()} | {:error, term()}
  def available_countries(opts \\ []) do
    plug = Keyword.get(opts, :plug, nil)

    req_opts = [decode_json: [keys: :atoms], receive_timeout: 10_000]
    req_opts = if plug, do: Keyword.put(req_opts, :plug, plug), else: req_opts

    case Req.get(@vies_status_url, req_opts) do
      {:ok, %Req.Response{status: 200, body: %{countries: countries}}} when is_list(countries) ->
        map = Map.new(countries, &{&1.countryCode, &1.availability == "Available"})
        {:ok, map}

      _ ->
        {:error, :vies_status_unavailable}
    end
  end

  # --- Private ---

  defp do_lookup(country_code, tin, opts) do
    plug = Keyword.get(opts, :plug, nil)

    json = %{countryCode: country_code, vatNumber: tin}

    req_opts = [json: json, decode_json: [keys: :atoms], receive_timeout: 15_000]
    req_opts = if plug, do: Keyword.put(req_opts, :plug, plug), else: req_opts

    case Req.post(@vies_check_url, req_opts) do
      {:ok, %Req.Response{body: %{valid: true} = body}} ->
        result = %{
          country_code: Map.get(body, :countryCode, country_code),
          afm: Map.get(body, :vatNumber, tin),
          onomasia: Map.get(body, :name, "") |> process_name(),
          commer_title: nil,
          address: Map.get(body, :address, "") |> process_address(),
          source: :vies
        }

        {:ok, result}

      {:ok, %Req.Response{body: %{valid: false}}} ->
        {:error, :invalid_vat}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:vies_http_error, status}}

      {:error, reason} ->
        {:error, {:vies_request_failed, reason}}
    end
  end

  defp process_name(name) do
    name
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp process_address(address) do
    address
    |> String.replace("\n", " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  # --- Caching ---

  defp cache_get(nil, _key), do: :miss
  defp cache_get(cache, key), do: VatchexVies.Cache.get(cache, key)

  defp cache_store(nil, _key, _result), do: :ok
  defp cache_store(cache, key, result), do: VatchexVies.Cache.put(cache, key, result)
end
