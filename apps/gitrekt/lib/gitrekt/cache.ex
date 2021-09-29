defmodule GitRekt.Cache do
  @moduledoc """
  Behaviour for caching Git operations.
  """

  @type cache :: term
  @type cache_key :: term
  @type cache_entry :: term

  @type op :: atom | tuple

  @doc """
  Initialize the cache for the given `path`.
  """
  @callback init_cache(path :: Path.t, opts :: keyword) :: cache

  @doc """
  Fetches the value for a specific `cache_key`.
  """
  @callback fetch_cache(cache, cache_key) :: cache_entry | nil

  @doc """
  Puts the given `cache_entry` under `cache_key`.
  """
  @callback put_cache(cache, cache_key, cache_entry) :: :ok

  @doc """
  Returns the cache key for the given `op` or `nil` if the operation should not be cached.
  """
  @callback make_cache_key(op) :: cache_key | nil
end
