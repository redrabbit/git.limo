defmodule GitGud.Comment do
  @moduledoc """
  Comment schema and helper functions.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias GitGud.DB
  alias GitGud.User
  alias GitGud.Repo

  schema "comments" do
    belongs_to :repo, Repo
    field :thread_table, :string
    belongs_to :author, User
    belongs_to :parent, __MODULE__
    has_many :children, __MODULE__, foreign_key: :parent_id
    field :body, :string
    timestamps()
  end

  @type t :: %__MODULE__{
    id: pos_integer,
    repo_id: pos_integer,
    repo: Repo.t,
    thread_table: binary,
    author_id: pos_integer,
    author: User.t,
    parent_id: pos_integer | nil,
    parent: t | nil,
    children: [t],
    body: binary,
    inserted_at: NaiveDateTime.t,
    updated_at: NaiveDateTime.t
  }

  @doc """
  Updates the given `repo` with the given `params`.

  ```elixir
  {:ok, comment} = GitGud.Comment.update(comment, body: "This is the **new** comment message.")
  ```

  This function validates the given `params` using `changeset/2`.
  """
  @spec update(t, map|keyword) :: {:ok, t} | {:error, Ecto.Changeset.t | :file.posix}
  def update(%__MODULE__{} = comment, params) do
    DB.update(changeset(comment, Map.new(params)))
  end

  @doc """
  Similar to `update/2`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec update!(t, map|keyword) :: t
  def update!(%__MODULE__{} = comment, params) do
    DB.update!(changeset(comment, Map.new(params)))
  end

  @doc """
  Deletes the given `comment`.
  """
  @spec delete(t) :: {:ok, t} | {:error, Ecto.Changeset.t}
  def delete(%__MODULE__{} = comment) do
    DB.delete(comment)
  end

  @doc """
  Similar to `delete!/1`, but raises an `Ecto.InvalidChangesetError` if an error occurs.
  """
  @spec delete!(t) :: t
  def delete!(%__MODULE__{} = comment) do
    DB.delete!(comment)
  end


  @doc """
  Returns a comment changeset for the given `params`.
  """
  @spec changeset(t, map) :: Ecto.Changeset.t
  def changeset(%__MODULE__{} = comment, params \\ %{}) do
    comment
    |> cast(params, [:repo_id, :thread_table, :author_id, :parent_id, :body])
    |> validate_required([:repo_id, :thread_table, :author_id, :body])
    |> assoc_constraint(:repo)
    |> assoc_constraint(:author)
    |> assoc_constraint(:parent)
  end

  #
  # Protocols
  #

  defimpl GitGud.AuthorizationPolicies do
    alias GitGud.Comment

    # Owner can do everything
    def can?(%Comment{author_id: user_id}, %User{id: user_id}, _action), do: true

    # Everybody can read comments.
    def can?(%Comment{}, _user, :read), do: true

    # Everything-else is forbidden.
    def can?(%Comment{}, _user, _actions), do: false
  end
end
