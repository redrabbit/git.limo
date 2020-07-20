defmodule GitRekt.GitAgent.Cache do
  @moduledoc """
  Behaviour for caching Git operations.
  """

  @type cache :: term
  @type cache_key :: term
  @type cache_entry :: term

  @type op :: atom | tuple

  @callback init_cache(path :: Path.t, opts :: keyword) :: cache
  @callback fetch_cache(cache, cache_key) :: cache_entry | nil
  @callback put_cache(cache, cache_key, cache_entry) :: :ok
  @callback make_cache_key(op) :: cache_key | nil
end
