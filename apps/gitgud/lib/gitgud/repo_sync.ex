defmodule GitGud.RepoSync do
  @moduledoc """
  Conveniences for fetching and pushing Git objects and meta objects.
  """

  alias Ecto.Multi

  alias GitRekt.Git
  alias GitRekt.WireProtocol.ReceivePack

  alias GitGud.DB
  alias GitGud.GitCommit
  alias GitGud.Repo

  import Ecto.Query, only: [from: 2]

  @batch_insert_chunk_size 5_000

  @doc """
  Writes the `receive_pack` objects and references.
  """
  @spec push(Repo.t, ReceivePack.t) :: {:ok, [ReceivePack.cmd], [Git.oid]} | {:error, term}
  def push(%Repo{} = repo, %ReceivePack{cmds: cmds} = receive_pack) do
    with {:ok, objs} <- push_objects(receive_pack, repo.id),
          :ok <- push_meta_objects(objs, repo.id),
          :ok <- push_references(receive_pack), do:
      {:ok, cmds, Map.keys(objs)}
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
    commit = extract_commit_props(data)
    author = Regex.named_captures(~r/^(?<name>.+) <(?<email>.+)> (?<time>[0-9]+) (?<time_offset>[-\+][0-9]{4})$/, commit["author"])
    {GitCommit, %{
      repo_id: repo_id,
      oid: oid,
      parents: Enum.map(List.wrap(commit["parent"] || []), &Git.oid_parse/1),
      message: commit["message"],
      author_name: author["name"],
      author_email: author["email"],
      gpg_signature: commit["gpgsig"],
      committed_at: DateTime.to_naive(DateTime.from_unix!(String.to_integer(author["time"])))
    }}
  end

  defp map_git_meta_object(_obj, _repo_id), do: nil

  defp extract_commit_props(data) do
    [header, message] = String.split(data, "\n\n", parts: 2)
    header
    |> String.split("\n", trim: true)
    |> Enum.chunk_by(&String.starts_with?(&1, " "))
    |> Enum.chunk_every(2)
    |> Enum.flat_map(fn
      [one] ->
        one
      [one, two] ->
        two = Enum.join(Enum.map(two, &String.trim_leading/1), "")
        List.update_at(one, -1, &(&1 <> two))
    end)
    |> Enum.map(fn line ->
      [key, val] = String.split(line, " ", parts: 2)
      {key, String.trim_trailing(val)}
    end)
    |> List.insert_at(0, {"message", message})
    |> Enum.reduce(%{}, fn {key, val}, acc -> Map.update(acc, key, val, &(List.wrap(val) ++ [&1])) end)
  end
end
