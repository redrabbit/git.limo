defmodule GitGud.Web.SSHAuthenticationKeyView do
  @moduledoc false
  use GitGud.Web, :view

  alias GitGud.SSHAuthenticationKey

  @spec ssh_key_fingerprint(SSHAuthenticationKey.t()) :: binary
  def ssh_key_fingerprint(ssh_key) do
    case :public_key.ssh_decode(ssh_key.data, :public_key) do
      [{decoded_key, _attrs}] ->
        to_string(:public_key.ssh_hostkey_fingerprint(decoded_key))
    end
  end

  @spec title(atom, map) :: binary
  def title(:index, _assigns), do: "SSH keys"
end
