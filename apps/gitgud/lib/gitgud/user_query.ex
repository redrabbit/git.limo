defmodule GitGud.UserQuery do
  @moduledoc """
  Conveniences for `GitGud.User` related queries.
  """

  alias GitGud.Authorization
  alias GitGud.DB
  alias GitGud.User

  @doc """
  Returns a user for the given `id`.
  """
  @spec by_id(pos_integer, keyword) :: User.t | nil
  def by_id(id, opts \\ []) do
    {{preloads, viewer}, opts} = extract_opts(opts)
    User
    |> DB.get(id, opts)
    |> DB.preload(preloads)
    |> filter_visible(viewer)
  end

  @doc """
  Returns a user for the given `username`.
  """
  @spec by_username(binary, keyword) :: User.t | nil
  def by_username(username, opts \\ []) do
    {{preloads, viewer}, opts} = extract_opts(opts)
    User
    |> DB.get_by([username: username], opts)
    |> DB.preload(preloads)
    |> filter_visible(viewer)
  end

  @doc """
  Returns a user for the given `email`.
  """
  @spec by_email(binary, keyword) :: User.t | nil
  def by_email(email, opts \\ []) do
    {{preloads, viewer}, opts} = extract_opts(opts)
    User
    |> DB.get_by([email: email], opts)
    |> DB.preload(preloads)
    |> filter_visible(viewer)
  end

  #
  # Helpers
  #

  defp filter_visible(nil, _viewer), do: nil
  defp filter_visible(%User{} = user, :granted), do: user
  defp filter_visible(%User{repositories: []} = user, _viewer), do: user
  defp filter_visible(%User{repositories: repos} = user, viewer) do
    %{user|repositories: Authorization.filter(viewer, repos, :read)}
  end

  defp extract_opts(opts) do
    {preloads, opts} = Keyword.pop(opts, :preload, [])
    {viewer, opts} = Keyword.pop(opts, :viewer, :granted)
    {{preloads, viewer}, opts}
  end
end
