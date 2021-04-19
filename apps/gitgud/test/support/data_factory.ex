defmodule GitGud.DataFactory do
  @moduledoc """
  This module provides functions to generate all kind of test data.
  """

  alias GitGud.User

  import Faker.Person, only: [name: 0]
  import Faker.Company, only: [catch_phrase: 0]
  import Faker.Internet, only: [user_name: 0]
  import Faker.Lorem, only: [sentence: 1, paragraph: 1]
  import Faker.Nato, only: [callsign: 0]

  @doc """
  Returns a map representing `GitGud.User` registration changeset params.
  """
  def user do
    %{
      name: name(),
      login: String.replace(user_name(), ~r/[^a-zA-Z0-9_-]/, "-", global: true),
      account: account(),
      emails: [email()]
    }
  end

  @doc """
  Returns a map representing `GitGud.Repo` changeset params.
  """
  def repo do
    %{name: String.downcase(callsign()), description: sentence(2..8), pushed_at: NaiveDateTime.utc_now()}
  end

  @doc """
  Returns a map representing `GitGud.Account` changeset params.
  """
  def account do
    %{password: "qwertz"}
  end

  @doc """
  Returns a map representing `GitGud.Email` changeset params.
  """
  def email do
    %{address: String.replace(Faker.Internet.email(), "'", "")}
  end

  @doc """
  Returns a map representing `GitGud.SSHKey` changeset params.
  """
  def ssh_key do
    {rsa_pub, rsa_priv} = make_ssh_pair(512)
    %{name: callsign(), data: rsa_pub, __priv__: rsa_priv}
  end

  @doc """
  Returns a map representing `GitGud.SSHKey` changeset params.
  """
  def ssh_key_strong do
    {rsa_pub, rsa_priv} = make_ssh_pair(2048)
    %{name: callsign(), data: rsa_pub, __priv__: rsa_priv}
  end

  @doc """
  Returns a map representing `GitGud.SSHKey` changeset params.
  """
  def ssh_key_strong(%User{id: user_id}), do: ssh_key_strong(user_id)
  def ssh_key_strong(user_id) when is_integer(user_id) do
    Map.put(ssh_key_strong(), :user_id, user_id)
  end

  @doc """
  Returns a map representing `GitGud.GPGKey` changeset params.
  """
  def gpg_key(%User{name: name, emails: emails}) do
    gpg_key(name, Enum.map(emails, &(&1.address)))
  end

  @doc """
  Returns a map representing `GitGud.GPGKey` changeset params.
  """
  def gpg_key(name, emails) do
    %{data: make_gpg_key(name, emails)}
  end

  @doc """
  Returns a map representing `GitGud.Issue` changeset params.
  """
  def issue() do
    %{title: catch_phrase(), comment: comment()}
  end

  @doc """
  Returns a map representing `GitGud.Comment` changeset params.
  """
  def comment do
    %{body: paragraph(2..5)}
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

  defp make_gpg_key(name, emails) do
    gen_key =
    Enum.reduce(emails, "%no-protection\n%pubring -\nKey-Type: default\nSubkey-Type: default", fn email, acc ->
      acc <> "\nName-Real: #{name}\nName-Email: #{email}"
    end)

    case System.cmd("sh", ["-c", "echo \"#{gen_key}\" | gpg --batch --gen-key --armor"]) do
      {armor, 0} -> armor
      {error, 1} -> raise "failed to generate GPG key: #{error}"
    end
  end
end
