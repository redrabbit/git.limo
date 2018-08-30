defmodule GitGud.UserQuery do
  @moduledoc """
  Conveniences for `GitGud.User` related queries.
  """

  alias GitGud.DB
  alias GitGud.User

  @doc """
  Returns a user for the given `username`.
  """
  @spec by_id(pos_integer, keyword) :: User.t | nil
  def by_id(id, opts \\ [])
  def by_id(id, []), do: DB.get(User, id)
  def by_id(id, opts) do
    {preload, opts} = Keyword.pop(opts, :preload)
    DB.preload(by_id(id, opts), preload)
  end

  @doc """
  Returns a user for the given `username`.
  """
  @spec by_username(binary, keyword) :: User.t | nil
  def by_username(username, opts \\ [])
  def by_username(username, []), do: DB.get_by(User, username: username)
  def by_username(username, opts) do
    {preload, opts} = Keyword.pop(opts, :preload)
    DB.preload(by_username(username, opts), preload)
  end

  @doc """
  Returns a user for the given `email`.
  """
  @spec by_email(binary, keyword) :: User.t | nil
  def by_email(email, opts \\ [])
  def by_email(email, []), do: DB.get_by(User, email: email)
  def by_email(email, opts) do
    {preload, opts} = Keyword.pop(opts, :preload)
    DB.preload(by_email(email, opts), preload)
  end
end
