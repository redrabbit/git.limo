defmodule GitGud.UserQuery do
  @moduledoc """
  Conveniences for `GitGud.User` related queries.
  """

  @behaviour GitGud.DBQueryable

  alias GitGud.DB
  alias GitGud.DBQueryable

  alias GitGud.User

  import Ecto.Query

  @doc """
  Returns a user for the given `id`.
  """
  @spec by_id(pos_integer, keyword) :: User.t | nil
  @spec by_id([pos_integer], keyword) :: [User.t]
  def by_id(id, opts \\ [])
  def by_id(ids, opts) when is_list(ids) do
    DB.all(DBQueryable.query({__MODULE__, :users_query}, [ids], opts))
  end

  def by_id(id, opts) do
    DB.one(DBQueryable.query({__MODULE__, :user_query}, id, opts))
  end

  @doc """
  Returns a user for the given `username`.
  """
  @spec by_username(binary, keyword) :: User.t | nil
  @spec by_username([binary], keyword) :: [User.t]
  def by_username(username, opts \\ [])
  def by_username(usernames, opts) when is_list(usernames) do
    DB.all(DBQueryable.query({__MODULE__, :users_query}, [:username, usernames], opts))
  end

  def by_username(username, opts) do
    DB.one(DBQueryable.query({__MODULE__, :user_query}, [:username, username], opts))
  end

  @doc """
  Returns a user for the given `email`.
  """
  @spec by_email(binary, keyword) :: User.t | nil
  @spec by_email([binary], keyword) :: [User.t]
  def by_email(email, opts \\ [])
  def by_email(emails, opts) when is_list(emails) do
    DB.all(DBQueryable.query({__MODULE__, :users_query}, [:email, emails], opts))
  end

  def by_email(email, opts) do
    DB.one(DBQueryable.query({__MODULE__, :user_query}, [:email, email], opts))
  end

  @doc """
  Returns a list of users matching the given `input`.
  """
  @spec search(binary, keyword) :: [User.t]
  def search(input, opts \\ []) do
    DB.all(DBQueryable.query({__MODULE__, :search_query}, input, opts))
  end

  @doc """
  Returns a query for fetching a single user by `id`.
  """
  @spec user_query(pos_integer) :: Ecto.Query.t
  def user_query(id) when is_integer(id), do: user_query(:id, id)

  @doc """
  Returns a query for fetching a single user by `key` and `val`.
  """
  @spec user_query(atom, term) :: Ecto.Query.t
  def user_query(key, val) do
    where(User, ^List.wrap({key, val}))
  end

  @doc """
  Returns a query for fetching users by `ids`.
  """
  @spec users_query([pos_integer]) :: Ecto.Query.t
  def users_query(ids) when is_list(ids) do
    from(u in User, where: u.id in ^ids)
  end

  @doc """
  Returns a query for fetching users by `key` and `vals`.
  """
  @spec users_query(atom, [binary]) :: Ecto.Query.t
  def users_query(:username = _key, vals) when is_list(vals) do
    from(u in User, where: u.username in ^vals)
  end

  def users_query(:email = _key, vals) when is_list(vals) do
    from(u in User, where: u.email in ^vals)
  end

  @doc """
  Returns a query for searching users.
  """
  @spec search_query(binary) :: Ecto.Query.t
  def search_query(input) do
    term = "%#{input}%"
    from(u in User, where: ilike(u.username, ^term))
  end

  #
  # Callbacks
  #

  @impl true
  def alter_query(query, [], _viewer), do: query

  @impl true
  def alter_query(query, [preload|tail], viewer) do
    query
    |> join_preload(preload, viewer)
    |> alter_query(tail, viewer)
  end

  #
  # Helpers
  #

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
end
