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
  @spec by_username([binary], keyword) :: [User.t]
  def by_username(username, opts \\ [])
  def by_username(usernames, opts) when is_list(usernames) do
    {params, opts} = extract_opts(opts)
    DB.all(user_query({:username, usernames}, params), opts)
  end

  def by_username(username, opts) do
    {params, opts} = extract_opts(opts)
    DB.one(user_query({:username, username}, params), opts)
  end

  @doc """
  Returns a user for the given `email`.
  """
  @spec by_email(binary, keyword) :: User.t | nil
  @spec by_email([binary], keyword) :: [User.t]
  def by_email(email, opts \\ [])
  def by_email(emails, opts) when is_list(emails) do
    {params, opts} = extract_opts(opts)
    DB.all(user_query({:email, emails}, params), opts)
  end

  def by_email(email, opts) do
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

  defp user_query({:username, val}) when is_list(val) do
    from(u in User, where: u.username in ^val)
  end

  defp user_query({:email, val}) when is_list(val) do
    from(u in User, where: u.email in ^val)
  end

  defp user_query({_key, _val} = where) do
    where(User, ^List.wrap(where))
  end

  defp user_query(match, {pagination, preloads, viewer}) do
    match
    |> user_query()
    |> exec_pagination(pagination)
    |> exec_preload(preloads, viewer)
  end

  defp user_search_query(search_term) do
    term = "%#{search_term}%"
    from(u in User, where: ilike(u.username, ^term))
  end

  defp user_search_query(match, {pagination, preloads, viewer}) do
    match
    |> user_search_query()
    |> exec_pagination(pagination)
    |> exec_preload(preloads, viewer)
  end

  defp exec_pagination(query, {nil, nil}), do: query
  defp exec_pagination(query, {offset, nil}), do: offset(query, ^offset)
  defp exec_pagination(query, {nil, limit}), do: limit(query, ^limit)
  defp exec_pagination(query, {offset, limit}) do
    query
    |> offset(^offset)
    |> limit(^limit)
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
    {offset, opts} = Keyword.pop(opts, :offset)
    {limit, opts} = Keyword.pop(opts, :limit)
    {preloads, opts} = Keyword.pop(opts, :preload, [])
    {viewer, opts} = Keyword.pop(opts, :viewer)
    {{{offset, limit}, List.wrap(preloads), viewer}, opts}
  end
end
