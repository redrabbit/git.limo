defmodule GitRekt.GitAgent do
  @moduledoc """
  High-level API for running Git commands on a repository.
  """
  use GenServer

  alias GitRekt.Git

  @type agent :: pid | Git.repo

  @type git_commit :: %{oid: Git.oid, type: :commit, commit: Git.commit}
  @type git_reference :: %{oid: Git.oid, name: binary, prefix: binary, type: :reference, subtype: :branch | :tag}
  @type git_tag :: %{oid: Git.oid, type: :tag, tag: Git.tag}
  @type git_blob :: %{oid: Git.oid, type: :blob, blob: Git.blob}
  @type git_tree :: %{oid: Git.oid, type: :tree, tree: Git.tree}
  @type git_tree_entry :: %{oid: Git.oid, name: binary, mode: integer, type: :tree_entry, subtype: :blob | :tree}
  @type git_diff :: %{type: :diff, diff: Git.diff}

  @type git_revision :: git_commit | git_reference | git_tag
  @type git_object :: git_revision | git_blob | git_tree

  @doc """
  Starts a Git agent linked to the current process for the repository at the given `path`.
  """
  @spec start_link(Path.t, keyword) :: GenServer.on_start
  def start_link(arg, opts \\ []), do: GenServer.start_link(__MODULE__, arg, opts)

  @doc """
  Returns the Git reference.
  """
  @spec head(agent) :: {:ok, git_reference} | {:error, term}
  def head(agent), do: call(agent, :head)

  @doc """
  Returns all Git branches.
  """
  @spec branches(agent) :: {:ok, [git_reference]} | {:error, term}
  def branches(agent), do: call(agent, {:references, "refs/heads/*"})

  @doc """
  Returns the Git branch with the given `name`.
  """
  @spec branch(agent, binary) :: {:ok, git_reference} | {:error, term}
  def branch(agent, name), do: call(agent, {:reference, "refs/heads/" <> name})

  @doc """
  Returns all Git tags.
  """
  @spec tags(agent) :: {:ok, [git_tag]} | {:error, term}
  def tags(agent), do: call(agent, {:references, "refs/tags/*"})

  @doc """
  Returns the Git tag with the given `name`.
  """
  @spec tag(agent, binary) :: {:ok, git_tag} | {:error, term}
  def tag(agent, name), do: call(agent, {:reference, "refs/tags/" <> name})

  @doc """
  Returns the Git tag author of the given `tag`.
  """
  @spec tag_author(agent, git_tag) :: {:ok, map} | {:error, term}
  def tag_author(agent, tag), do: call(agent, {:author, tag})

  @doc """
  Returns the Git tag message of the given `tag`.
  """
  @spec tag_message(agent, git_tag) :: {:ok, binary} | {:error, term}
  def tag_message(agent, tag), do: call(agent, {:message, tag})

  @doc """
  Returns all Git references matching the given `glob`.
  """
  @spec references(agent, binary | :undefined) :: {:ok, [git_reference]} | {:error, term}
  def references(agent, glob \\ :undefined), do: call(agent, {:references, glob})

  @doc """
  Returns the Git reference with the given `name`.
  """
  @spec reference(agent, binary) :: {:ok, git_reference} | {:error, term}
  def reference(agent, name), do: call(agent, {:reference, name})

  @doc """
  Returns the Git object with the given `oid`.
  """
  @spec object(agent, Git.oid) :: {:ok, git_object} | {:error, term}
  def object(agent, oid), do: call(agent, {:object, oid})

  @doc """
  Returns the Git object matching the given `spec`.
  """
  @spec revision(agent, binary) :: {:ok, git_object, git_reference | nil} | {:error, term}
  def revision(agent, spec), do: call(agent, {:revision, spec})

  @doc """
  Returns the parent of the given `commit`.
  """
  @spec commit_parents(agent, git_commit) :: {:ok, [git_commit]} | {:error, term}
  def commit_parents(agent, commit), do: call(agent, {:commit_parents, commit})

  @doc """
  Returns the author of the given `commit`.
  """
  @spec commit_author(agent, git_commit) :: {:ok, map} | {:error, term}
  def commit_author(agent, commit), do: call(agent, {:author, commit})

  @doc """
  Returns the message of the given `commit`.
  """
  @spec commit_message(agent, git_commit) :: {:ok, binary} | {:error, term}
  def commit_message(agent, commit), do: call(agent, {:message, commit})

  @doc """
  Returns the timestamp of the given `commit`.
  """
  @spec commit_timestamp(agent, git_commit) :: {:ok, DateTime.t} | {:error, term}
  def commit_timestamp(agent, commit), do: call(agent, {:commit_timestamp, commit})

  @doc """
  Returns the GPG signature of the given `commit`.
  """
  @spec commit_gpg_signature(agent, git_commit) :: {:ok, binary} | {:error, term}
  def commit_gpg_signature(agent, commit), do: call(agent, {:commit_gpg_signature, commit})

  @doc """
  Returns the content of the given `blob`.
  """
  @spec blob_content(agent, git_blob) :: {:ok, binary} | {:error, term}
  def blob_content(agent, blob), do: call(agent, {:blob_content, blob})

  @doc """
  Returns the size in byte of the given `blob`.
  """
  @spec blob_size(agent, git_blob) :: {:ok, non_neg_integer} | {:error, term}
  def blob_size(agent, blob), do: call(agent, {:blob_size, blob})

  @doc """
  Returns the Git tree of the given `obj`.
  """
  @spec tree(agent, git_object) :: {:ok, git_tree} | {:error, term}
  def tree(agent, obj), do: call(agent, {:tree, obj})

  @doc """
  Returns the Git tree entries of the given `obj`.
  """
  @spec tree_entries(agent, git_object) :: {:ok, [git_tree_entry]} | {:error, term}
  def tree_entries(agent, obj), do: call(agent, {:tree_entries, obj})

  @doc """
  Returns the Git tree entry for the given `obj` and `oid`.
  """
  @spec tree_entry_by_id(agent, git_object, Git.oid) :: {:ok, git_tree_entry} | {:error, term}
  def tree_entry_by_id(agent, obj, oid), do: call(agent, {:tree_entry, obj, {:oid, oid}})

  @doc """
  Returns the Git tree entry for the given `obj` and `path`.
  """
  @spec tree_entry_by_id(agent, git_object, Path.t) :: {:ok, git_tree_entry} | {:error, term}
  def tree_entry_by_path(agent, obj, path), do: call(agent, {:tree_entry, obj, {:path, path}})

  @doc """
  Returns the Git tree target of the given `tree_entry`.
  """
  @spec tree_entry_target(agent, git_tree_entry) :: {:ok, git_blob | git_tree} | {:error, term}
  def tree_entry_target(agent, tree_entry), do: call(agent, {:tree_entry_target, tree_entry})

  @doc """
  Returns the Git diff of `obj1` and `obj2`.
  """
  @spec diff(agent, git_object, git_object, keyword) :: {:ok, git_diff} | {:error, term}
  def diff(agent, obj1, obj2, opts \\ []), do: call(agent, {:diff, obj1, obj2, opts})

  @doc """
  Returns the deltas of the given `diff`.
  """
  @spec diff_deltas(agent, git_diff) :: {:ok, map} | {:error, term}
  def diff_deltas(agent, diff), do: call(agent, {:diff_deltas, diff})

  @doc """
  Returns a binary formated representation of the given `diff`.
  """
  @spec diff_format(agent, git_diff, Git.diff_format) :: {:ok, binary} | {:error, term}
  def diff_format(agent, diff, format \\ :patch), do: call(agent, {:diff_format, diff, format})

  @doc """
  Returns the stats of the given `diff`.
  """
  @spec diff_stats(agent, git_diff) :: {:ok, map} | {:error, term}
  def diff_stats(agent, diff), do: call(agent, {:diff_stats, diff})

  @doc """
  Returns the Git commit history of the given `obj`.
  """
  @spec history(agent, git_object) :: {:ok, [git_commit]} | {:error, term}
  def history(agent, obj, opts \\ []), do: call(agent, {:history, obj, opts})

  @doc """
  Returns the underlying Git commit of the given `obj`.
  """
  @spec peel(agent, git_reference | git_tag) :: {:ok, git_commit} | {:error, term}
  def peel(agent, obj), do: call(agent, {:peel, obj})

  #
  # Callbacks
  #

  @impl true
  def init(arg) do
    case Git.repository_load(arg) do
      {:ok, handle} ->
        {:ok, handle}
      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_call({:references, _glob} = op, _from, handle) do
    {:reply, call_stream(op, handle), handle}
  end

  @impl true
  def handle_call({:commit_list, _commit} = op, _from, handle) do
    {:reply, call_stream(op, handle), handle}
  end

  @impl true
  def handle_call({:tree_entries, _tree} = op, _from, handle) do
    {:reply, call_stream(op, handle), handle}
  end

  @impl true
  def handle_call({:history, _obj, _opts} = op, from, handle) do
    case call_stream(op, handle) do
      {:ok, stream} ->
        {:noreply, handle, {:continue, {:history, stream, from}}}
      {:error, reason} ->
        {:reply, {:error, reason}, handle}
    end
  end

  @impl true
  def handle_call(op, _from, handle) do
    {:reply, call(op, handle), handle}
  end

  @impl true
  def handle_continue({:history, stream, from}, handle) do
    :ok = GenServer.reply(from, {:ok, Enum.to_list(stream)})
    {:noreply, handle}
  end

  #
  # Helpers
  #

  defp call(%{__agent__: agent}, op), do: call(agent, op)
  defp call(agent, op) when is_pid(agent), do: GenServer.call(agent, op)
  defp call(agent, op) when is_reference(agent), do: call(op, agent)

  defp call(:head, handle) do
    case Git.reference_resolve(handle, "HEAD") do
      {:ok, name, shorthand, oid} ->
        {:ok, resolve_reference({name, shorthand, :oid, oid})}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp call({:reference, "/refs/" <> _suffix = name}, handle) do
    case Git.reference_lookup(handle, name) do
      {:ok, shorthand, :oid, oid} ->
        {:ok, resolve_reference({name, shorthand, :oid, oid})}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp call({:reference, shorthand}, handle) do
    case Git.reference_dwim(handle, shorthand) do
      {:ok, name, :oid, oid} ->
        {:ok, resolve_reference({name, shorthand, :oid, oid})}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp call({:references, glob}, handle) do
    case Git.reference_stream(handle, glob) do
      {:ok, stream} ->
        {:ok, Stream.map(stream, &resolve_reference/1)}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp call({:revision, spec}, handle) do
    case Git.revparse_ext(handle, spec) do
      {:ok, obj, obj_type, oid, name} ->
        {:ok, resolve_object({obj, obj_type, oid}), resolve_reference({name, nil, :oid, oid})}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp call({:object, oid}, handle) do
    case Git.object_lookup(handle, oid) do
      {:ok, obj_type, obj} ->
        {:ok, resolve_object({obj, obj_type, oid})}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp call({:tree, obj}, handle), do: fetch_tree(obj, handle)
  defp call({:diff, obj1, obj2, opts}, handle), do: fetch_diff(obj1, obj2, handle, opts)
  defp call({:diff_format, %{type: :diff, diff: diff}, format}, _handle), do: Git.diff_format(diff, format)
  defp call({:diff_deltas, %{type: :diff, diff: diff}}, _handle) do
    case Git.diff_deltas(diff) do
      {:ok, deltas} ->
        {:ok, Enum.map(deltas, &resolve_diff_delta/1)}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp call({:diff_stats, %{type: :diff, diff: diff}}, _handle) do
    case Git.diff_stats(diff) do
      {:ok, files_changed, insertions, deletions} ->
        {:ok, resolve_diff_stats({files_changed, insertions, deletions})}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp call({:tree_entry, obj, spec}, handle), do: fetch_tree_entry(obj, spec, handle)
  defp call({:tree_entry_target, %{oid: oid, subtype: type}}, handle) do
    case Git.object_lookup(handle, oid) do
      {:ok, ^type, obj} ->
        {:ok, resolve_object({obj, type, oid})}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp call({:tree_entries, obj}, handle), do: fetch_tree_entries(obj, handle)
  defp call({:author, obj}, _handle), do: fetch_author(obj)
  defp call({:message, obj}, _handle), do: fetch_message(obj)
  defp call({:commit_parents, %{type: :commit, commit: commit}}, _handle) do
    case Git.commit_parents(commit) do
      {:ok, stream} ->
        {:ok, Stream.map(stream, &resolve_commit_parent/1)}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp call({:commit_timestamp, %{type: :commit, commit: commit}}, _handle) do
    case Git.commit_time(commit) do
      {:ok, time, _offset} ->
        DateTime.from_unix(time)
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp call({:commit_gpg_signature, %{type: :commit, commit: commit}}, _handle), do: Git.commit_header(commit, "gpgsig")
  defp call({:blob_content, %{type: :blob, blob: blob}}, _handle), do: Git.blob_content(blob)
  defp call({:blob_size, %{type: :blob, blob: blob}}, _handle), do: Git.blob_content(blob)
  defp call({:history, obj, opts}, handle), do: walk_history(obj, handle, opts)
  defp call({:peel, obj}, handle), do: fetch_target(obj, handle)

  defp call_stream(op, handle) do
    case call(op, handle) do
      {:ok, stream} ->
        {:ok, enumerate_stream(stream)}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp resolve_reference({nil, nil, :oid, _oid}), do: nil
  defp resolve_reference({name, nil, :oid, oid}) do
    prefix = Path.dirname(name) <> "/"
    shorthand = Path.basename(name)
    %{oid: oid, name: shorthand, prefix: prefix, type: :reference, subtype: resolve_reference_type(prefix)}
  end

  defp resolve_reference({name, shorthand, :oid, oid}) do
    prefix = String.slice(name, 0, String.length(name) - String.length(shorthand))
    %{oid: oid, name: shorthand, prefix: prefix, type: :reference, subtype: resolve_reference_type(prefix)}
  end

  defp resolve_reference_type("refs/heads/"), do: :branch
  defp resolve_reference_type("refs/tags/"), do: :tag

  defp resolve_object({blob, :blob, oid}), do: %{oid: oid, type: :blob, blob: blob}
  defp resolve_object({commit, :commit, oid}), do: %{oid: oid, type: :commit, commit: commit}
  defp resolve_object({tree, :tree, oid}), do: %{oid: oid, type: :tree, tree: tree}
  defp resolve_object({tag, :tag, oid}) do
    case Git.tag_name(tag) do
      {:ok, name} ->
        %{oid: oid, name: name, type: :tag, tag: tag}
      {:error, _reason} ->
        %{oid: oid, type: :tag, tag: tag}
    end
  end

  defp resolve_commit_parent({oid, commit}), do: %{oid: oid, type: :commit, commit: commit}

  defp resolve_tree_entry({mode, type, oid, name}), do: %{oid: oid, name: name, mode: mode, type: :tree_entry, subtype: type}

  defp resolve_diff_delta({{old_file, new_file, count, similarity}, hunks}) do
    %{old_file: resolve_diff_file(old_file), new_file: resolve_diff_file(new_file), count: count, similarity: similarity, hunks: Enum.map(hunks, &resolve_diff_hunk/1)}
  end

  defp resolve_diff_file({oid, path, size, mode}) do
    %{oid: oid, path: path, size: size, mode: mode}
  end

  defp resolve_diff_hunk({{header, old_start, old_lines, new_start, new_lines}, lines}) do
    %{header: header, old_start: old_start, old_lines: old_lines, new_start: new_start, new_lines: new_lines, lines: Enum.map(lines, &resolve_diff_line/1)}
  end

  defp resolve_diff_line({origin, old_line_no, new_line_no, num_lines, content_offset, content}) do
    %{origin: <<origin>>, old_line_no: old_line_no, new_line_no: new_line_no, num_lines: num_lines, content_offset: content_offset, content: content}
  end

  defp resolve_diff_stats({files_changed, insertions, deletions}) do
    %{files_changed: files_changed, insertions: insertions, deletions: deletions}
  end

  defp lookup_object!(oid, handle) do
    case Git.object_lookup(handle, oid) do
      {:ok, obj_type, obj} ->
        resolve_object({obj, obj_type, oid})
      {:error, reason} ->
        raise reason
    end
  end

  defp fetch_tree(%{type: :commit, commit: commit}, _handle) do
    case Git.commit_tree(commit) do
      {:ok, oid, tree} ->
        {:ok, %{oid: oid, type: :tree, tree: tree}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_tree(%{type: :reference, name: name, prefix: prefix}, handle) do
    case Git.reference_peel(handle, prefix <> name) do
      {:ok, obj_type, oid, obj} ->
        fetch_tree(resolve_object({obj, obj_type, oid}), handle)
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_tree(%{type: :tag, tag: tag}, handle) do
    case Git.tag_peel(tag) do
      {:ok, obj_type, oid, obj} ->
        fetch_tree(resolve_object({obj, obj_type, oid}), handle)
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_tree_entry(%{type: :tree, tree: tree}, {:oid, oid}, _handle) do
    case Git.tree_byid(tree, oid) do
      {:ok, mode, type, oid, name} ->
        {:ok, resolve_tree_entry({mode, type, oid, name})}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_tree_entry(%{type: :tree, tree: tree}, {:path, path}, _handle) do
    case Git.tree_bypath(tree, path) do
      {:ok, mode, type, oid, name} ->
        {:ok, resolve_tree_entry({mode, type, oid, name})}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_tree_entry(obj, spec, handle) do
    case fetch_tree(obj, handle) do
      {:ok, tree} ->
        fetch_tree_entry(tree, spec, handle)
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_tree_entries(%{type: :tree, tree: tree}, _handle) do
    case Git.tree_entries(tree) do
      {:ok, stream} ->
        {:ok, Stream.map(stream, &resolve_tree_entry/1)}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_tree_entries(obj, handle) do
    case fetch_tree(obj, handle) do
      {:ok, tree} ->
        fetch_tree_entries(tree, handle)
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_diff(%{type: :tree, tree: tree1}, %{type: :tree, tree: tree2}, handle, opts) do
    case Git.diff_tree(handle, tree1, tree2, opts) do
      {:ok, diff} ->
        {:ok, %{type: :diff, diff: diff}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_diff(obj1, obj2, handle, opts) do
    with {:ok, tree1} <- fetch_tree(obj1, handle),
         {:ok, tree2} <- fetch_tree(obj2, handle), do:
      fetch_diff(tree1, tree2, handle, opts)
  end

  defp fetch_target(%{type: :reference, name: name, prefix: prefix}, handle) do
    case Git.reference_peel(handle, prefix <> name) do
      {:ok, obj_type, oid, obj} ->
        {:ok, resolve_object({obj, obj_type, oid})}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_target(%{type: :tag, tag: tag}, _handle) do
    case Git.tag_peel(tag) do
      {:ok, obj_type, oid, obj} ->
        {:ok, resolve_object({obj, obj_type, oid})}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp fetch_author(%{type: :commit, commit: commit}) do
    with {:ok, name, email, time, _offset} <- Git.commit_author(commit),
         {:ok, datetime} <- DateTime.from_unix(time), do:
      {:ok, %{name: name, email: email, timestamp: datetime}}
  end

  defp fetch_author(%{type: :tag, tag: tag}) do
    with {:ok, name, email, time, _offset} <- Git.tag_author(tag),
         {:ok, datetime} <- DateTime.from_unix(time), do:
      {:ok, %{name: name, email: email, timestamp: datetime}}
  end

  defp fetch_message(%{type: :commit, commit: commit}), do: Git.commit_message(commit)
  defp fetch_message(%{type: :tag, tag: tag}), do: Git.tag_message(tag)

  defp walk_history(obj, handle, opts) do
    {sorting, opts} = Enum.split_with(opts, &(is_atom(&1) && String.starts_with?(to_string(&1), "sort")))
    with {:ok, walk} <- Git.revwalk_new(handle),
          :ok <- Git.revwalk_sorting(walk, sorting),
          :ok <- Git.revwalk_push(walk, obj.oid),
         {:ok, stream} <- Git.revwalk_stream(walk) do
      stream = Stream.map(stream, &lookup_object!(&1, handle))
      if pathspec = Keyword.get(opts, :pathspec),
        do: {:ok, Stream.filter(stream, &pathspec_match_commit(&1, List.wrap(pathspec), handle))},
      else: {:ok, stream}
    end
  end

  defp pathspec_match_commit(%{type: :commit, commit: commit}, pathspec, handle) do
    with {:ok, _oid, tree} <- Git.commit_tree(commit),
         {:ok, match?} <- Git.pathspec_match_tree(tree, pathspec) do
      match? && pathspec_match_commit_tree(commit, tree, pathspec, handle)
    else
      {:error, _reason} -> false
    end
  end

  defp pathspec_match_commit_tree(commit, tree, pathspec, handle) do
    with {:ok, stream} <- Git.commit_parents(commit),
         {_oid, parent} <- Enum.at(stream, 0, :initial_commit),
         {:ok, _oid, parent_tree} <- Git.commit_tree(parent),
         {:ok, delta_count} <- pathspec_match_commit_diff(parent_tree, tree, pathspec, handle) do
      delta_count > 0
    else
      :initial_commit -> false
      {:error, _reason} -> false
    end
  end

  defp pathspec_match_commit_diff(old_tree, new_tree, pathspec, handle) do
    case Git.diff_tree(handle, old_tree, new_tree, pathspec: pathspec) do
      {:ok, diff} -> Git.diff_delta_count(diff)
      {:error, reason} -> {:error, reason}
    end
  end

  defp enumerate_stream(stream) when is_function(stream), do: %Stream{enum: Enum.to_list(stream)}
  defp enumerate_stream(%Stream{} = stream), do: Map.update!(stream, :enum, &Enum.to_list/1)
end
