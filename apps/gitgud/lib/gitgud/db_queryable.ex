defmodule GitGud.DBQueryable do
  @moduledoc """
  Behaviour for implementing generic queries.
  """

  import Ecto.Query

  alias GitGud.DB

  @callback alter_query(query :: Ecto.Query.t, preloads :: term, viewer :: GitGud.User.t | nil) :: Ecto.Query.t

  @doc """
  Returns a single result from the given queryable.
  """
  @spec one({module, atom}, term, keyword) :: term
  def one(callback, args, opts \\ []) do
    {params, opts} = extract_opts(opts)
    DB.one(build_query(callback, args, params), opts)
  end

  @doc """
  Returns all results matching the given queryable.
  """
  @spec all({module, atom}, term, keyword) :: [term]
  def all(callback, args, opts \\ []) do
    {params, opts} = extract_opts(opts)
    DB.all(build_query(callback, args, params), opts)
  end

  @doc """
  Returns a query for the given queryable.
  """
  @spec query({module, atom}, term, keyword) :: Ecto.Query.t
  def query(callback, args, opts \\ []) do
    {params, _opts} = extract_opts(opts)
    build_query(callback, args, params)
  end

  #
  # Helpers
  #

  defp build_query({module, function_name}, args, params) do
    exec_query(apply(module, function_name, List.wrap(args)), module, params)
  end

  defp exec_query(query, module, {pagination, preloads, viewer}) do
    query
    |> exec_pagination(pagination)
    |> exec_preload(module, preloads, viewer)
  end

  defp exec_pagination(query, {nil, nil}), do: query
  defp exec_pagination(query, {offset, nil}), do: offset(query, ^offset)
  defp exec_pagination(query, {nil, limit}), do: limit(query, ^limit)
  defp exec_pagination(query, {offset, limit}) do
    query
    |> offset(^offset)
    |> limit(^limit)
  end

  defp exec_preload(query, module, preloads, viewer) do
    apply(module, :alter_query, [query, preloads, viewer])
  end

  defp extract_opts(opts) do
    {offset, opts} = Keyword.pop(opts, :offset)
    {limit, opts} = Keyword.pop(opts, :limit)
    {preloads, opts} = Keyword.pop(opts, :preload, [])
    {viewer, opts} = Keyword.pop(opts, :viewer)
    {{{offset, limit}, List.wrap(preloads), viewer}, opts}
  end
end
