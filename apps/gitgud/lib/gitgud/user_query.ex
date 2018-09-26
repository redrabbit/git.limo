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
  def by_id(id, opts \\ []) do
    DB.one(DBQueryable.query({__MODULE__, :query}, id, opts))
  end

  @doc """
  Returns a user for the given `username`.
  """
  @spec by_username(binary, keyword) :: User.t | nil
  @spec by_username([binary], keyword) :: [User.t]
  def by_username(username, opts \\ [])
  def by_username(usernames, opts) when is_list(usernames) do
    DB.all(DBQueryable.query({__MODULE__, :query}, {:username, usernames}, opts))
  end

  def by_username(username, opts) do
    DB.one(DBQueryable.query({__MODULE__, :query}, {:username, username}, opts))
  end

  @doc """
  Returns a user for the given `email`.
  """
  @spec by_email(binary, keyword) :: User.t | nil
  @spec by_email([binary], keyword) :: [User.t]
  def by_email(email, opts \\ [])
  def by_email(emails, opts) when is_list(emails) do
    DB.all(DBQueryable.query({__MODULE__, :query}, {:email, emails}, opts))
  end

  def by_email(email, opts) do
    DB.one(DBQueryable.query({__MODULE__, :query}, {:email, email}, opts))
  end

  def search(input, opts \\ []) do
    DB.all(DBQueryable.query({__MODULE__, :search_query}, input, opts))
  end

  @doc """
  Returns a query for fetching users.
  """
  @spec query({atom, term}) :: Ecto.Query.t
  def query({:username, val} = _arg) when is_list(val) do
    from(u in User, where: u.username in ^val)
  end

  def query({:email, val}) when is_list(val) do
    from(u in User, where: u.email in ^val)
  end

  def query({_key, _val} = where) do
    where(User, ^List.wrap(where))
  end

  @spec query(pos_integer) :: Ecto.Query.t
  def query(id) when is_integer(id) do
    where(User, id: ^id)
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
