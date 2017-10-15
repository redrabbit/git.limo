defmodule GitGud.SSHAuthenticationKey do
  use Ecto.Schema

  alias GitGud.User

  schema "ssh_authentication_keys" do
    belongs_to  :user, User
    field       :key, :string
    timestamps()
  end

  @type t :: %__MODULE__{
    id: pos_integer,
    user_id: pos_integer,
    user: User.t,
    key: binary,
    inserted_at: NaiveDateTime.t,
    updated_at: NaiveDateTime.t
  }
end
