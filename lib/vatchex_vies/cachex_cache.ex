# SPDX-FileCopyrightText: 2026 Isaak Tsalicoglou <isaak@waseigo.com>
# SPDX-License-Identifier: Apache-2.0

if Code.ensure_loaded?(Cachex) do
  defmodule VatchexVies.CachexCache do
    @moduledoc """
    Cachex adapter for `VatchexVies.Cache` protocol.

    Configure in your application config:

        config :vatchex_vies, :cache_name, :vatchex_vies
        config :vatchex_vies, :cache_ttl, 86_400_000  # 24 hours

    The Cachex instance must be started in your supervision tree:

        children = [
          {Cachex, name: :vatchex_vies, limit: 10_000},
          ...
        ]
    """

    @default_cache :vatchex_vies
    @default_ttl 86_400_000

    def get(cache \\ @default_cache, key) do
      case Cachex.get(cache, key) do
        {:ok, nil} -> :miss
        {:ok, value} -> {:ok, value}
        _ -> :miss
      end
    end

    def put(cache \\ @default_cache, key, value, opts \\ []) do
      ttl =
        Keyword.get(opts, :ttl) || Application.get_env(:vatchex_vies, :cache_ttl, @default_ttl)

      Cachex.put(cache, key, value, expiration: ttl)
    end
  end
end
