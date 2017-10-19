defmodule GitGud.UserQuerySet do
  @moduledoc """
  Conveniences for `GitGud.User` related queries.
  """
  alias GitGud.Repo
  alias GitGud.User

  @doc """
  Returns a user for the given `username_or_id`.
  """
  @spec get(binary|pos_integer, keyword) :: User.t | nil
  def get(username_or_id, opts \\ [])
  def get(username_or_id, []) do
    cond do
      is_integer(username_or_id) ->
        Repo.get(User, username_or_id)
      is_binary(username_or_id) ->
        Repo.get_by(User, username: username_or_id)
      true ->
        nil
    end
  end

  def get(username_or_id, opts) do
    {preload, opts} = Keyword.pop(opts, :preload)
    Repo.preload(get(username_or_id, opts), preload)
  end

end
