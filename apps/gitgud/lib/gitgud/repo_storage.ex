defmodule GitGud.RepoStorage do
  @moduledoc """
  Conveniences for storing Git objects and meta objects.
  """

  alias GitRekt.Git

  alias GitGud.Repo

  @doc """
  Initializes a new Git repository for the given `repo`.
  """
  @spec init(Repo.t, boolean) :: {:ok, Git.repo} | {:error, term}
  def init(%Repo{} = repo, bare?) do
    Git.repository_init(workdir(repo), bare?)
  end

  @doc """
  Updates the workdir for the given `repo`.
  """
  @spec rename(Repo.t, Repo.t) :: {:ok, Path.t} | {:error, term}
  def rename(%Repo{} = old_repo, %Repo{} = repo) do
    old_workdir = workdir(old_repo)
    new_workdir = workdir(repo)
    case File.rename(old_workdir, new_workdir) do
      :ok -> {:ok, new_workdir}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Removes Git objects and references associated to the given `repo`.
  """
  @spec cleanup(Repo.t) :: {:ok, [Path.t]} | {:error, term}
  def cleanup(%Repo{} = repo) do
    File.rm_rf(workdir(repo))
  end

  @doc """
  Returns the absolute path to the Git workdir for the given `repo`.

  The path is a concatenation of the Git root path, `repo.owner_login` and `repo.name`.
  """
  @spec workdir(Repo.t) :: Path.t
  def workdir(%Repo{} = repo) do
    Path.join([Keyword.fetch!(Application.get_env(:gitgud, __MODULE__), :git_root), repo.owner_login, repo.name])
  end
end
