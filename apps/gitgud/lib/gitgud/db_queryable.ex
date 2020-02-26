defmodule GitGud.DBQueryable do
  @moduledoc """
  Behaviour for implementing generic queries.
  """

  import Ecto.Query, only: [order_by: 2, offset: 2, limit: 2]

  @callback query(name :: atom, args :: [term]) :: Ecto.Query.t
  @callback alter_query(query :: Ecto.Query.t, preloads :: term, viewer :: GitGud.User.t | nil) :: Ecto.Query.t

  @doc """
  Returns a query for the given `queryable`.
  """
  @spec query({module, atom}, term, keyword) :: Ecto.Query.t
  def query(queryable, args, opts \\ []) do
    {params, _opts} = extract_opts(opts)
    build_query(queryable, args, params)
  end

  #
  # Helpers
  #

  defp build_query({module, function_name}, args, params) do
    exec_query(apply(module, :query, [function_name, List.wrap(args)]), module, params)
  end

  defp exec_query(query, module, {sort, pagination, preloads, viewer}) do
    query
    |> alter(module, preloads, viewer)
    |> order_by(^sort)
    |> paginate(pagination)
  end

  defp paginate(query, {nil, nil}), do: query
  defp paginate(query, {offset, nil}), do: offset(query, ^offset)
  defp paginate(query, {nil, limit}), do: limit(query, ^limit)
  defp paginate(query, {offset, limit}) do
    query
    |> offset(^offset)
    |> limit(^limit)
  end

  defp alter(query, module, preloads, viewer) do
    apply(module, :alter_query, [query, preloads, viewer])
  end

  defp extract_opts(opts) do
    {order_by, opts} = Keyword.pop(opts, :order_by)
    {offset, opts} = Keyword.pop(opts, :offset)
    {limit, opts} = Keyword.pop(opts, :limit)
    {preloads, opts} = Keyword.pop(opts, :preload, [])
    {viewer, opts} = Keyword.pop(opts, :viewer)
    {{order_by, {offset, limit}, List.wrap(preloads), viewer}, opts}
  end
end
