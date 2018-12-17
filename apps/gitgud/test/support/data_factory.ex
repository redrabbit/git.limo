defmodule GitGud.DataFactory do
  @moduledoc """
  This module provides functions to generate all kind of test data.
  """

  alias GitGud.User

  import Faker.Name, only: [name: 0]
  import Faker.Internet, only: [user_name: 0]
  import Faker.Lorem, only: [sentence: 1]
  import Faker.Nato, only: [callsign: 0]

  @doc """
  Returns a map representing `GitGud.User` registration params.
  """
  def user do
    %{
      name: name(),
      login: String.replace(user_name(), ~r/[^a-zA-Z0-9_-]/, "-", global: true),
      auth: auth(),
      emails: [email()]
    }
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

  def auth do
    %{password: "qwertz"}
  end

  @doc """
  Returns a map representing `GitGud.Email` params.
  """
  def email do
    %{address: String.replace(Faker.Internet.email(), "'", "")}
  end

  @doc """
  Returns a map representing `GitGud.Email` params.
  """
  def email(%User{id: user_id}), do: email(user_id)
  def email(user_id) do
    Map.put(email(), :user_id, user_id)
  end

  @doc """
  Returns a map representing `GitGud.SSHKey` params.
  """
  def ssh_key do
    {rsa_pub, rsa_priv} = make_ssh_pair(128)
    %{name: callsign(), data: rsa_pub, __priv__: rsa_priv}
  end

  @doc """
  Returns a map representing `GitGud.SSHKey` params.
  """
  def ssh_key(%User{id: user_id}), do: ssh_key(user_id)
  def ssh_key(user_id) when is_integer(user_id) do
    Map.put(ssh_key(), :user_id, user_id)
  end

  @doc """
  Returns a map representing `GitGud.SSHKey` params.
  """
  def ssh_key_strong do
    {rsa_pub, rsa_priv} = make_ssh_pair(2048)
    %{name: callsign(), data: rsa_pub, __priv__: rsa_priv}
  end

  @doc """
  Returns a map representing `GitGud.SSHKey` params.
  """
  def ssh_key_strong(%User{id: user_id}), do: ssh_key_strong(user_id)
  def ssh_key_strong(user_id) when is_integer(user_id) do
    Map.put(ssh_key_strong(), :user_id, user_id)
  end

  @doc false
  defmacro __using__(_opts) do
    quote do
      def factory(name, params \\ []) do
        apply(unquote(__MODULE__), name, List.wrap(params))
      end
    end
  end

  #
  # Helpers
  #

  defp make_ssh_pair(bit_size) do
    {rsa_priv, 0} = System.cmd("sh", ["-c", "openssl genrsa #{bit_size} 2>/dev/null"])
    {rsa_pubk, 0} = System.cmd("sh", ["-c", "echo \"#{rsa_priv}\" | openssl pkey -pubout | ssh-keygen -i -f /dev/stdin -m PKCS8"])
    {rsa_pubk, rsa_priv}
  end
end
