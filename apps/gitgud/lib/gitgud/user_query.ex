defmodule GitGud.UserQuery do
  @moduledoc """
  Conveniences for `GitGud.User` related queries.
  """

  alias GitGud.QuerySet
  alias GitGud.User

  @doc """
  Returns a user for the given `username_or_id`.
  """
  @spec get(binary|pos_integer, keyword) :: User.t | nil
  def get(username_or_id, opts \\ [])
  def get(username_or_id, []) do
    cond do
      is_integer(username_or_id) ->
        QuerySet.get(User, username_or_id)
      is_binary(username_or_id) ->
        QuerySet.get_by(User, username: username_or_id)
      true ->
        nil
    end
  end

  def get(username_or_id, opts) do
    {preload, opts} = Keyword.pop(opts, :preload)
    QuerySet.preload(get(username_or_id, opts), preload)
  end
end
