# SPDX-FileCopyrightText: 2026 Isaak Tsalicoglou <isaak@waseigo.com>
# SPDX-License-Identifier: Apache-2.0

defprotocol VatchexVies.Cache do
  @moduledoc """
  Protocol for cache adapters used by `VatchexVies.lookup/3`.
  """

  @doc """
  Looks up a cached value by key. Returns `{:ok, value}` or `:miss`.
  """
  def get(cache, key)

  @doc """
  Stores a value in the cache. The `opts` keyword list may include:

  - `:ttl` — time-to-live in milliseconds (adapter may fall back to its own default or app config)
  """
  def put(cache, key, value, opts)
end

defimpl VatchexVies.Cache, for: Atom do
  def get(VatchexVies.CachexCache, key) do
    if Code.ensure_loaded?(VatchexVies.CachexCache) do
      apply(VatchexVies.CachexCache, :get, [key])
    else
      :miss
    end
  end

  def get(_, _), do: :miss

  def put(VatchexVies.CachexCache, key, value, opts) do
    if Code.ensure_loaded?(VatchexVies.CachexCache) do
      apply(VatchexVies.CachexCache, :put, [key, value, opts])
    else
      :ok
    end
  end

  def put(_, _, _, _), do: :ok
end
