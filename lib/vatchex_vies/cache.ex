# SPDX-FileCopyrightText: 2024 Isaak Tsalicoglou <isaak@waseigo.com>
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
  Stores a value in the cache.
  """
  def put(cache, key, value)
end
