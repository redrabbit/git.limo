defmodule GitGud.RepoSync do
  @moduledoc """
  Conveniences for storing Git objects and meta objects.
  """

  alias Ecto.Multi

  alias GitRekt.Git
  alias GitRekt.WireProtocol.ReceivePack

  alias GitGud.DB
  alias GitGud.Commit
  alias GitGud.Repo

  import Ecto.Changeset, only: [change: 2]
  import Ecto.Query, only: [from: 2]

  @batch_insert_chunk_size 5_000

  @doc """
  Writes the given `receive_pack` objects and references to the given `repo`.

  This function is called by `GitGud.SSHServer` and `GitGud.SmartHTTPBackend` on each push command.
  It is responsible for writing objects and references to the underlying Git repository.

  See `GitRekt.WireProtocol.ReceivePack` and `GitGud.RepoSync.push/2` for more details.
  """
  @spec push(Repo.t, ReceivePack.t) :: {:ok, [ReceivePack.cmd], [Git.oid]} | {:error, term}
  def push(%Repo{} = repo, %ReceivePack{cmds: cmds} = receive_pack) do
    with {:ok, objs} <- push_objects(receive_pack, repo.id),
          :ok <- push_meta_objects(objs, repo.id),
          :ok <- push_references(receive_pack),
         {:ok, repo} <- DB.update(change(repo, %{pushed_at: NaiveDateTime.truncate(NaiveDateTime.utc_now(), :second)})) do
      if Application.get_application(:gitgud_web),
        do: Phoenix.PubSub.broadcast(GitGud.Web.PubSub, "repo:#{repo.id}", {:push, %{refs: cmds, oids: Map.keys(objs)}}),
      else: :ok
    end
  end

  #
  # Helpers
  #

  defp push_objects(receive_pack, repo_id) do
    if Application.get_env(:gitgud, :git_storage, :filesystem) == :postgres do
      objs = resolve_git_objects_postgres(receive_pack, repo_id)
      case DB.transaction(write_git_objects(objs, repo_id)) do
        {:ok, _} -> {:ok, objs}
      end
    else
      ReceivePack.apply_pack(receive_pack, :write_dump)
    end
  end

  defp push_meta_objects(objs, repo_id) do
    case DB.transaction(write_git_meta_objects(objs, repo_id)) do
      {:ok, _} -> :ok
    end
  end

  defp push_references(receive_pack), do: ReceivePack.apply_cmds(receive_pack)

  defp write_git_objects(objs, repo_id) do
    objs
    |> Enum.map(&map_git_object(&1, repo_id))
    |> Enum.chunk_every(@batch_insert_chunk_size)
    |> Enum.with_index()
    |> Enum.reduce(Multi.new(), &write_git_objects_multi/2)
  end

  defp write_git_meta_objects(objs, repo_id) do
    objs
    |> Enum.map(&map_git_meta_object(&1, repo_id))
    |> Enum.reject(&is_nil/1)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.reduce(Multi.new(), &write_git_meta_objects_multi/2)
  end

  defp write_git_objects_multi({objs, i}, multi) do
    Multi.insert_all(multi, {:chunk, i}, "git_objects", objs, on_conflict: {:replace, [:data]}, conflict_target: [:repo_id, :oid])
  end

  defp write_git_meta_objects_multi({schema, {objs, i}}, multi) do
    Multi.insert_all(multi, {schema, {:chunk, i}}, schema, objs)
  end

  defp write_git_meta_objects_multi({schema, objs}, multi) when length(objs) > @batch_insert_chunk_size do
    objs
    |> Enum.chunk_every(@batch_insert_chunk_size)
    |> Enum.with_index()
    |> Enum.reduce(multi, &write_git_meta_objects_multi({schema, &1}, &2))
  end

  defp write_git_meta_objects_multi({schema, objs}, multi) do
    Multi.insert_all(multi, {schema, :all}, schema, objs)
  end

  defp resolve_git_objects_postgres(receive_pack, repo_id) do
    receive_pack
    |> ReceivePack.resolve_pack()
    |> resolve_remaining_git_delta_objects(repo_id)
  end

  defp resolve_remaining_git_delta_objects({objs, []}, _repo_id), do: objs
  defp resolve_remaining_git_delta_objects({objs, delta_refs}, repo_id) do
    source_oids = Enum.map(delta_refs, &elem(&1, 0))
    source_objs = Map.new(DB.all(from o in "git_objects", where: o.repo_id == ^repo_id and o.oid in ^source_oids, select: {o.oid, {o.type, o.data}}), fn
      {oid, {obj_type, obj_data}} -> {oid, {map_git_object_type(obj_type), obj_data}}
    end)
    {new_objs, []} = ReceivePack.resolve_delta_objects(source_objs, delta_refs)
    Map.merge(objs, new_objs)
  end

  defp map_git_object({oid, {obj_type, obj_data}}, repo_id) do
    %{repo_id: repo_id, oid: oid, type: map_git_object_db_type(obj_type), size: byte_size(obj_data), data: obj_data}
  end

  defp map_git_object_type(1), do: :commit
  defp map_git_object_type(2), do: :tree
  defp map_git_object_type(3), do: :blob
  defp map_git_object_type(4), do: :tag

  defp map_git_object_db_type(:commit), do: 1
  defp map_git_object_db_type(:tree), do: 2
  defp map_git_object_db_type(:blob), do: 3
  defp map_git_object_db_type(:tag), do: 4

  defp map_git_meta_object({oid, {:commit, data}}, repo_id) do
    {Commit, Map.merge(Commit.decode(data), %{repo_id: repo_id, oid: oid})}
  end

  defp map_git_meta_object(_obj, _repo_id), do: nil
end
