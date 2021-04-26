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
  alias GitGud.UserQuery
  alias GitGud.Repo
  alias GitGud.GPGKey

  alias GitGud.Issue
  alias GitGud.IssueQuery

  import Ecto.Query, only: [from: 2, select: 3]

  require Logger

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
  Pushes the given `receive_pack` to the given `repo`.

  This function is called by `GitGud.SSHServer` and `GitGud.SmartHTTPBackend` when pushing changes. It is
  responsible for writing Git objects and references to the underlying ODB.
  """
  @spec push_pack(Repo.t, User.t, ReceivePack.t) :: {:ok, GitAgent.t, [ReceivePack.cmd], [any]} | {:error, term}
  def push_pack(%Repo{} = repo, %User{} = user, %ReceivePack{agent: agent, cmds: cmds} = receive_pack) do
    with  :ok <- check_pack(repo, user, receive_pack),
         {:ok, objs} <- ReceivePack.apply_pack(receive_pack, :write_dump),
          :ok <- ReceivePack.apply_cmds(receive_pack), do:
      {:ok, agent, cmds, objs}
  end

  @doc """
  Pushes meta informations for the given `cmds` and `objs` to the given `repo`.

  This function is called after all necessary Git objects and references have been written to the ODB. It is
  reponsible for writing meta informations to the database.
  """
  @spec push_meta(Repo.t, User.t, GitAgent.agent, [ReceivePack.cmd], [any]) :: :ok | {:error, term}
  def push_meta(%Repo{} = repo, %User{} = user, agent, cmds, objs) do
    with {:ok, repo} <- Repo.push(repo, user, agent, cmds),
         {:ok, meta} <- push_meta_objects(repo, user, agent, objs), do:
      dispatch_events(repo, cmds, meta)
  end

  @doc """
  Returns the absolute path to the Git workdir for the given `repo`.

  The path is a concatenation of the Git root path, `repo.owner_login` and `repo.name`.
  """
  @spec workdir(Repo.t) :: Path.t
  def workdir(%Repo{} = repo) do
    Path.join([Application.fetch_env!(:gitgud, :git_root), repo.owner_login, repo.name])
  end

  #
  # Helpers
  #

  defp check_pack(_repo, _user, _receive_pack), do: :ok

  defp push_meta_objects(repo, user, agent, objs) do
    case DB.transaction(write_git_meta_objects(repo, user, agent, objs), timeout: :infinity) do
      {:ok, meta} ->
        {:ok, meta}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp write_git_meta_objects(repo, user, agent, objs) do
    objs
    |> Enum.map(&map_git_meta_object(agent, &1))
    |> Enum.reject(&is_nil/1)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.reduce(Multi.new(), &write_git_meta_objects_multi(repo, user, &1, &2))
  end

  defp write_git_meta_objects_multi(repo, user, {:commit, commits}, multi) do
    batch = {user, batch_commits_users(commits)}
    multi
    |> insert_contributors_multi(repo, batch, commits)
    |> reference_issues_multi(repo, batch, commits)
  end

  defp map_git_meta_object(agent, {oid, %GitCommit{} = commit}) do
    with {:ok, author} <- GitAgent.commit_author(agent, commit),
         {:ok, committer} <- GitAgent.commit_committer(agent, commit),
         {:ok, message} <- GitAgent.commit_message(agent, commit),
         {:ok, parents} <- GitAgent.commit_parents(agent, commit),
         {:ok, timestamp} <- GitAgent.commit_timestamp(agent, commit) do
      gpg_sig =
        case GitAgent.commit_gpg_signature(agent, commit) do
          {:ok, gpg_sig} -> gpg_sig
          {:error, _reason} -> nil
        end
      {:commit, %{
        oid: oid,
        parents: Enum.map(parents, &(&1.oid)),
        message: message,
        author_name: author.name,
        author_email: author.email,
        committer_name: committer.name,
        committer_email: committer.email,
        gpg_key_id: extract_commit_gpg_key_id(gpg_sig),
        committer_at: timestamp,
      }}
    else
      {:error, reason} ->
        raise reason
    end
  end

  defp map_git_meta_object(_agent, {oid, {:commit, data}}) do
    commit = extract_commit_props(data)
    author = extract_commit_author(commit)
    committer = extract_commit_committer(commit)
    {:commit, %{
      oid: oid,
      parents: extract_commit_parents(commit),
      message: strip_utf8(commit["message"]),
      author_name: strip_utf8(author["name"]),
      author_email: strip_utf8(author["email"]),
      committer_name: strip_utf8(committer["name"]),
      committer_email: strip_utf8(committer["email"]),
      gpg_key_id: extract_commit_gpg_key_id(commit["gpgsig"]),
      committed_at: author["time"],
    }}
  end

  defp map_git_meta_object(_agent, _obj), do: nil

  defp batch_commits_users(commits) do
    emails = Enum.uniq(Enum.flat_map(commits, &[&1.author_email, &1.committer_email]))
    emails
    |> UserQuery.by_email(preload: :emails)
    |> Enum.map(fn user -> if email = Enum.find(user.emails, &(&1.verified && &1.address in emails)), do: {email.address, user} end)
    |> Enum.reject(&is_nil/1)
    |> Map.new()
  end

  defp insert_contributors_multi(multi, repo, {_user, users}, _commits) do
    contributors = Enum.map(users, fn {_email, user} -> %{repo_id: repo.id, user_id: user.id} end)
    unless Enum.empty?(contributors),
      do: Multi.insert_all(multi, :contributors, "repositories_contributors", contributors, on_conflict: :nothing),
    else: multi
  end

  defp reference_issues_multi(multi, repo, {user, users}, commits) do
    commits =
      Enum.reduce(commits, %{}, fn commit, acc ->
        refs = Regex.scan(~r/\B#([0-9]+)\b/, commit.message, capture: :all_but_first)
        refs = List.flatten(refs)
        refs = Enum.map(refs, &String.to_integer/1)
        unless Enum.empty?(refs),
          do: Map.put(acc, commit.oid, {Map.get(users, commit.committer_email, user), refs}),
        else: acc
      end)

    unless Enum.empty?(commits) do
      query = IssueQuery.query(:repo_issues_query, [repo.id, Enum.uniq(Enum.flat_map(commits, fn {_oid, {_user, refs}} -> refs end))])
      query = select(query, [issue: i], {i.id, i.number})
      Enum.reduce(DB.all(query), multi, fn {id, number}, multi ->
        case Enum.find_value(commits, fn {oid, {user, refs}} -> number in refs && {oid, user} end) do
          {oid, user} ->
            event = %{type: "commit_reference", commit_hash: Git.oid_fmt(oid), user_id: user.id, repo_id: repo.id, timestamp: NaiveDateTime.utc_now()}
            Multi.update_all(multi, {:issue_reference, id}, from(i in Issue, where: i.id == ^id, select: i), push: [events: event])
          nil ->
            multi
        end
      end)
    else
      multi
    end
  end

  defp dispatch_events(_repo, _cmds, meta) do
    dispatch_issue_reference_events(meta)
  end

  defp dispatch_issue_reference_events(meta) do
    meta
    |> Enum.filter(&meta_reference_issue?/1)
    |> Enum.map(fn {{:issue_reference, _issue_id}, {1, [issue]}} -> issue end)
    |> Enum.each(&broadcast_issue_event/1)
  end

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

  defp extract_commit_gpg_key_id(nil), do: nil
  defp extract_commit_gpg_key_id(gpg_sig) do
    gpg_sig
    |> GPGKey.decode!()
    |> GPGKey.parse!()
    |> get_in([:sig, :sub_pack, :issuer])
  end

  defp meta_reference_issue?({{:issue_reference, _issue_id}, _val}), do: true
  defp meta_reference_issue?(_multi_result), do: false

  defp broadcast_issue_event(issue) do
    GitGud.Web.Endpoint.broadcast("issue:#{issue.id}", "reference_commit", %{event: List.last(issue.events)})
  # Absinthe.Subscription.publish(GitGud.Web.Endpoint, List.last(issue.events), issue_event: issue.id)
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
