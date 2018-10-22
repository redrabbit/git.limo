defmodule GitGud.DB do
  @moduledoc """
  Single source of data, mediates between domain and data mapping layer.
  """

  use Ecto.Repo,
    otp_app: :gitgud,
    adapter: Ecto.Adapters.Postgres

  @doc """
  Dynamically loads the repository url from the
  DATABASE_URL environment variable.
  """
  def init(_, opts) do
    {:ok, Keyword.put(opts, :url, System.get_env("DATABASE_URL"))}
  end
end
