defmodule GitGud.RepoStorage do
  @moduledoc """
  Conveniences for storing Git objects and meta objects.
  """

  alias Ecto.Multi

  alias GitRekt.Git
  alias GitRekt.GitAgent
  alias GitRekt.GitCommit
  alias GitRekt.WireProtocol.ReceivePack

  alias GitGud.DB

  alias GitGud.User
  alias GitGud.Repo
  alias GitGud.GPGKey

  alias GitGud.Issue
  alias GitGud.IssueQuery

  import Ecto.Changeset, only: [change: 2]
  import Ecto.Query, only: [from: 2, select: 3]

  @batch_insert_chunk_size 5_000

  @doc """
  Initializes a new Git repository for the given `repo`.
  """
  @spec init(Repo.t, boolean) :: {:ok, Git.repo} | {:error, term}
  def init(%Repo{} = repo, bare?) do
    Git.repository_init(workdir(repo), bare?)
  end

  @doc """
  Renames the given `repo`.
  """
  @spec rename(Repo.t, Repo.t) :: {:ok, Path.t} | {:error, term}
  def rename(%Repo{} = repo, %Repo{} = old_repo) do
    old_workdir = workdir(old_repo)
    new_workdir = workdir(repo)
    case File.rename(old_workdir, new_workdir) do
      :ok -> {:ok, new_workdir}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Removes associated data for the given `repo`.
  """
  @spec cleanup(Repo.t) :: {:ok, [Path.t]} | {:error, term}
  def cleanup(%Repo{} = repo) do
    File.rm_rf(workdir(repo))
  end

  @doc """
  Writes the given `receive_pack` objects and references to the given `repo`.

  This function is called by `GitGud.SSHServer` and `GitGud.SmartHTTPBackend` on each push command.
  It is responsible for writing objects and references to the underlying Git repository.
  """
  @spec push(Repo.t, User.t, ReceivePack.t) :: {:ok, [Git.oid]} | {:error, term}
  def push(%Repo{} = repo, %User{} = user, %ReceivePack{} = receive_pack) do
    with {:ok, objs} <- ReceivePack.apply_pack(receive_pack, :write_dump),
         {:ok, meta} <- push_meta_objects(objs, repo, user),
          :ok <- ReceivePack.apply_cmds(receive_pack),
         {:ok, repo} <- DB.update(change(repo, %{pushed_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)})),
          :ok <- dispatch_events(repo, meta), do:
      {:ok, Map.keys(objs)}
  end

  @doc """
  Pushes the given `commit` to the given `repo`.
  """
  @spec push_commit(Repo.t, User.t, GitCommit.t) :: :ok | {:error, term}
  def push_commit(%Repo{} = repo, %User{} = user, %GitCommit{oid: oid} = commit) do
    with {:ok, meta} <- push_meta_objects([{oid, commit}], repo, user),
         {:ok, repo} <- DB.update(change(repo, %{pushed_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)})), do:
      dispatch_events(repo, meta)
  end

  @doc """
  Returns the absolute path to the Git workdir for the given `repo`.

  The path is a concatenation of the Git root path, `repo.owner.login` and `repo.name`.
  """
  @spec workdir(Repo.t) :: Path.t
  def workdir(%Repo{} = repo) do
    repo = DB.preload(repo, :owner)
    Path.join([Application.fetch_env!(:gitgud, :git_root), repo.owner.login, repo.name])
  end

  #
  # Helpers
  #

  defp push_meta_objects(objs, repo, user) do
    case DB.transaction(write_git_meta_objects(objs, repo, user), timeout: :infinity) do
      {:ok, multi_results} ->
        {:ok, multi_results}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp write_git_meta_objects(objs, repo, user) do
    objs
    |> Enum.map(&map_git_meta_object(&1, repo))
    |> Enum.reject(&is_nil/1)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.reduce(Multi.new(), &write_git_meta_objects_multi(&1, &2, repo, user))
  end

  defp write_git_meta_objects_multi({:commit, {commits, _i}}, multi, repo, user) do
    reference_issues_multi(multi, repo, user, commits)
  end

  defp write_git_meta_objects_multi({schema, {objs, i}}, multi, _repo, _user) do
    Multi.insert_all(multi, {schema, {:chunk, i}}, schema, objs)
  end

  defp write_git_meta_objects_multi({schema, objs}, multi, repo, user) when length(objs) > @batch_insert_chunk_size do
    objs
    |> Enum.chunk_every(@batch_insert_chunk_size)
    |> Enum.with_index()
    |> Enum.reduce(multi, &write_git_meta_objects_multi({schema, &1}, &2, repo, user))
  end

  defp write_git_meta_objects_multi({:commit, commits}, multi, repo, user) do
    reference_issues_multi(multi, repo, user, commits)
  end

  defp write_git_meta_objects_multi({schema, objs}, multi, _repo, _user) do
    Multi.insert_all(multi, {schema, :all}, schema, objs)
  end

  defp reference_issues_multi(multi, repo, user, commits) do
    commits =
      Enum.reduce(commits, %{}, fn commit, acc ->
        refs = Regex.scan(~r/\B#([0-9]+)\b/, commit.message, capture: :all_but_first)
        refs = List.flatten(refs)
        refs = Enum.map(refs, &String.to_integer/1)
        unless Enum.empty?(refs),
          do: Map.put(acc, commit.oid, refs),
        else: acc
      end)

    query = IssueQuery.query(:repo_issues_query, [repo.id, Enum.uniq(List.flatten(Map.values(commits)))])
    query = select(query, [issue: i], {i.id, i.number})
    Enum.reduce(DB.all(query), multi, fn {id, number}, multi ->
      if oid = Enum.find_value(commits, fn {oid, refs} -> number in refs && oid end) do
        event = %{type: "commit_reference", commit_hash: Git.oid_fmt(oid), user_id: user.id, repo_id: repo.id, timestamp: NaiveDateTime.utc_now()}
        Multi.update_all(multi, {:issue_reference, id}, from(i in Issue, where: i.id == ^id, select: i), push: [events: event])
      else
        multi
      end
    end)
  end

  defp dispatch_events(_repo, meta) do
    meta
    |> Enum.filter(fn {{:issue_reference, _issue_id}, _val} -> true
                      {_key, _val} -> false end)
    |> Enum.map(fn {{:issue_reference, _issue_id}, {1, [issue]}} -> issue end)
    |> Enum.each(&Absinthe.Subscription.publish(GitGud.Web.Endpoint, List.last(&1.events), issue_event: &1.id))
  end

  defp map_git_meta_object({oid, %GitCommit{} = commit}, repo) do
    with {:ok, author} <- GitAgent.commit_author(repo, commit),
         {:ok, committer} <- GitAgent.commit_committer(repo, commit),
         {:ok, message} <- GitAgent.commit_message(repo, commit),
         {:ok, parents} <- GitAgent.commit_parents(repo, commit),
    #    {:ok, gpg_signature} <- GitAgent.commit_gpg_signature(repo, commit),
         {:ok, timestamp} <- GitAgent.commit_timestamp(repo, commit) do
      {:commit, %{
        oid: oid,
        repo_id: repo.id,
        parents: Enum.map(parents, &(&1.oid)),
        message: message,
        author_name: author.name,
        author_email: author.email,
        committer_name: committer.name,
        committer_email: committer.email,
    #   gpg_key_id: gpg_signature,
        committer_at: timestamp,
      }}
    else
      {:error, reason} ->
        raise reason
    end
  end

  defp map_git_meta_object({oid, {:commit, data}}, repo) do
    commit = extract_commit_props(data)
    author = extract_commit_author(commit)
    committer = extract_commit_committer(commit)
    {:commit, %{
      oid: oid,
      repo_id: repo.id,
      parents: extract_commit_parents(commit),
      message: strip_utf8(commit["message"]),
      author_name: strip_utf8(author["name"]),
      author_email: strip_utf8(author["email"]),
      committer_name: strip_utf8(committer["name"]),
      committer_email: strip_utf8(committer["email"]),
      gpg_key_id: extract_commit_gpg_key_id(commit),
      committed_at: author["time"],
    }}
  end

  defp map_git_meta_object(_obj, _repo), do: nil

  defp extract_commit_props(data) do
    [header, message] = String.split(data, "\n\n", parts: 2)
    header
    |> String.split("\n", trim: true)
    |> Enum.chunk_by(&String.starts_with?(&1, " "))
    |> Enum.chunk_every(2)
    |> Enum.flat_map(fn
      [one] -> one
      [one, two] ->
        two = Enum.join(Enum.map(two, &String.trim_leading/1), "\n")
        List.update_at(one, -1, &Enum.join([&1, two], "\n"))
    end)
    |> Enum.map(fn line ->
      [key, val] = String.split(line, " ", parts: 2)
      {key, String.trim_trailing(val)}
    end)
    |> List.insert_at(0, {"message", message})
    |> Enum.reduce(%{}, fn {key, val}, acc -> Map.update(acc, key, val, &(List.wrap(val) ++ [&1])) end)
  end

  defp extract_commit_parents(commit) do
    Enum.map(List.wrap(commit["parent"] || []), &Git.oid_parse/1)
  end

  defp extract_commit_author(commit) do
    ~r/^(?<name>.+) <(?<email>.+)> (?<time>[0-9]+) (?<time_offset>[-\+][0-9]{4})$/
    |> Regex.named_captures(commit["author"])
    |> Map.update!("time", &DateTime.to_naive(DateTime.from_unix!(String.to_integer(&1))))
  end

  defp extract_commit_committer(commit) do
    ~r/^(?<name>.+) <(?<email>.+)> (?<time>[0-9]+) (?<time_offset>[-\+][0-9]{4})$/
    |> Regex.named_captures(commit["committer"])
    |> Map.update!("time", &DateTime.to_naive(DateTime.from_unix!(String.to_integer(&1))))
  end

  defp extract_commit_gpg_key_id(commit) do
    if gpg_signature = commit["gpgsig"] do
      gpg_signature
      |> GPGKey.decode!()
      |> GPGKey.parse!()
      |> get_in([:sig, :sub_pack, :issuer])
    end
  end

  defp strip_utf8(str) do
    strip_utf8_helper(str, [])
  end

  defp strip_utf8_helper(<<x :: utf8>> <> rest, acc), do: strip_utf8_helper(rest, [x|acc])
  defp strip_utf8_helper(<<_x>> <> rest, acc), do: strip_utf8_helper(rest, acc)
  defp strip_utf8_helper("", acc) do
    acc
    |> Enum.reverse()
    |> List.to_string()
  end
end
