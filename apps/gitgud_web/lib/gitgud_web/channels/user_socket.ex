defmodule GitGud.Web.UserSocket do
  @moduledoc """
  Module providing support for bidirectional communication between clients and server.
  """
  use Phoenix.Socket
  use Absinthe.Phoenix.Socket, schema: GitGud.GraphQL.Schema

  alias GitGud.UserQuery

  channel "commit_line_review:*", GitGud.Web.CommentThreadChannel
  channel "issue:*", GitGud.Web.CommentThreadChannel

  def connect(params, sock) do
    if token = params["token"],
      do: authenticate_socket(sock, token),
    else: {:ok, sock}
  end

  def id(_sock), do: nil

  #
  # Helpers
  #

  defp authenticate_socket(sock, token) do
    with {:ok, user_id} <- Phoenix.Token.verify(sock, "bearer", token, max_age: 86400),
         {:ok, user} <- find_user(user_id), do:
      {:ok, assign_user(sock, user)}
  end

  defp find_user(user_id) do
    if user = UserQuery.by_id(user_id),
      do: {:ok, user},
    else: {:error, :invalid}
  end

  defp assign_user(sock, user) do
    sock
    |> assign(:current_user, user)
    |> Absinthe.Phoenix.Socket.put_options(context: %{current_user: user})
  end
end
