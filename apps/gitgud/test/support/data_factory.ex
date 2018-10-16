defmodule GitGud.DataFactory do
  @moduledoc """
  This module provides functions to generate all kind of test data.
  """

  alias GitGud.User

  import Faker.Name, only: [name: 0]
  import Faker.Internet, only: [email: 0, user_name: 0]
  import Faker.Lorem, only: [sentence: 1]
  import Faker.Nato, only: [callsign: 0]

  @doc """
  Returns a map representing `GitGud.User` registration params.
  """
  def user do
    %{name: name(), username: String.replace(user_name(), ~r/[^a-zA-Z0-9_-]/, "-", global: true), email: String.replace(email(), "'", ""), password: "qwertz"}
  end

  @doc """
  Returns a map representing `GitGud.Repo` params.
  """
  def repo do
    %{name: String.downcase(callsign()), description: sentence(2..8)}
  end

  @doc """
  Returns a map representing `GitGud.Repo` params.
  """
  def repo(%User{id: user_id}), do: repo(user_id)
  def repo(user_id) when is_integer(user_id) do
    Map.put(repo(), :owner_id, user_id)
  end

  @doc """
  Returns a map representing `GitGud.SSHKey` params.
  """
  def ssh_key do
    {ssh_rsa, 0} = System.cmd("sh", ["-c", "openssl genrsa 128 2>/dev/null | openssl pkey -pubout | ssh-keygen -i -f /dev/stdin -m PKCS8"])
    %{name: callsign(), data: ssh_rsa}
  end

  @doc """
  Returns a map representing `GitGud.SSHKey` params.
  """
  def ssh_key(%User{id: user_id}), do: ssh_key(user_id)
  def ssh_key(user_id) when is_integer(user_id) do
    Map.put(ssh_key(), :user_id, user_id)
  end

  @doc false
  defmacro __using__(_opts) do
    quote do
      def factory(name, params \\ []) do
        apply(unquote(__MODULE__), name, List.wrap(params))
      end
    end
  end
end
