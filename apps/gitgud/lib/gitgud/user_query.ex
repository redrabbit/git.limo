defmodule GitGud.UserQuery do
  @moduledoc """
  Conveniences for `GitGud.User` related queries.
  """

  alias GitGud.DB
  alias GitGud.User

  import Ecto.Query

  @doc """
  Returns a user for the given `id`.
  """
  @spec by_id(pos_integer, keyword) :: User.t | nil
  def by_id(id, opts \\ []) do
    {params, opts} = extract_opts(opts)
    DB.one(user_query(id, params), opts)
  end

  @doc """
  Returns a user for the given `username`.
  """
  @spec by_username(binary, keyword) :: User.t | nil
  def by_username(username, opts \\ []) do
    {params, opts} = extract_opts(opts)
    DB.one(user_query({:username, username}, params), opts)
  end

  @doc """
  Returns a user for the given `email`.
  """
  @spec by_email(binary, keyword) :: User.t | nil
  def by_email(email, opts \\ []) do
    {params, opts} = extract_opts(opts)
    DB.one(user_query({:email, email}, params), opts)
  end

  def search(term, opts \\ []) do
    {params, opts} = extract_opts(opts)
    DB.all(user_search_query(term, params), opts)
  end

  #
  # Helpers
  #

  defp user_query(id) when is_integer(id) do
    where(User, id: ^id)
  end

  defp user_query({_key, _val} = where) do
    where(User, ^List.wrap(where))
  end

  defp user_query(match, {preloads, viewer}) do
    exec_preload(user_query(match), preloads, viewer)
  end

  defp user_search_query(search_term) do
    term = "%#{search_term}%"
    from(u in User, where: ilike(u.username, ^term))
  end

  defp user_search_query(match, {preloads, viewer}) do
    exec_preload(user_search_query(match), preloads, viewer)
  end

  defp exec_preload(query, [], _viewer), do: query
  defp exec_preload(query, [preload|tail], viewer) do
    query
    |> join_preload(preload, viewer)
    |> exec_preload(tail, viewer)
  end

  defp join_preload(query, :repositories, nil) do
    query
    |> join(:left, [u], r in assoc(u, :repositories), r.public == true)
    |> preload([u, r], [repositories: r])
  end

  defp join_preload(query, :repositories, viewer) do
    query
    |> join(:left, [u], m in "repositories_maintainers", m.user_id == ^viewer.id)
    |> join(:left, [u, m], r in assoc(u, :repositories), r.public == true or r.owner_id == ^viewer.id or m.repo_id == r.id)
    |> preload([u, m, r], [repositories: r])
  end

  defp join_preload(query, preload, _viewer) do
    preload(query, ^preload)
  end

  defp extract_opts(opts) do
    {preloads, opts} = Keyword.pop(opts, :preload, [])
    {viewer, opts} = Keyword.pop(opts, :viewer)
    {{List.wrap(preloads), viewer}, opts}
  end
end
