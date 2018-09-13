defmodule GitRekt.WireProtocol.ReceivePack do
  @moduledoc """
  Module implementing the `git-receive-pack` command.
  """

  @behaviour GitRekt.WireProtocol.Service

  alias GitRekt.Git

  import GitRekt.WireProtocol, only: [reference_discovery: 2]

  defstruct [:repo, state: :disco, caps: [], cmds: [], pack: []]

  @null_oid String.duplicate("0", 40)

  @type cmd :: {
    :create | :update | :delete,
    Git.oid,
    Git.oid,
  }

  @type t :: %__MODULE__{
    repo: Git.repo,
    state: :disco | :update_req | :pack | :done,
    caps: [binary],
    cmds: [],
    pack: Packfile.obj_list,
  }

  #
  # Callbacks
  #

  @impl true
  def next(%__MODULE__{state: :disco} = handle, [:flush|lines]) do
    {%{handle|state: :done}, lines, reference_discovery(handle.repo, "git-receive-pack")}
  end

  @impl true
  def next(%__MODULE__{state: :disco} = handle, lines) do
    {%{handle|state: :update_req}, lines, reference_discovery(handle.repo, "git-receive-pack")}
  end

  @impl true
  def next(%__MODULE__{state: :update_req} = handle, [:flush|lines]) do
    {%{handle|state: :done}, lines, []}
  end

  @impl true
  def next(%__MODULE__{state: :update_req} = handle, lines) do
    {_shallows, lines} = Enum.split_while(lines, &obj_match?(&1, :shallow))
    {cmds, lines} = Enum.split_while(lines, &is_binary/1)
    {caps, cmds} = parse_caps(cmds)
    [:flush|lines] = lines
    {%{handle|state: :pack, caps: caps, cmds: parse_cmds(cmds)}, lines, []}
  end

  @impl true
  def next(%__MODULE__{state: :pack} = handle, lines) do
    {%{handle|state: :done, pack: lines}, [], []}
  end

  @impl true
  def next(%__MODULE__{state: :done} = handle, []) do
    :ok = apply_pack(handle.repo, handle.pack)
    :ok = apply_cmds(handle.repo, handle.cmds)
    if "report-status" in handle.caps,
      do: {handle, [], report_status(handle.cmds)},
    else: {handle, [], []}
  end

  @impl true
  def skip(%__MODULE__{state: :disco} = handle), do: %{handle|state: :update_req}
  def skip(%__MODULE__{state: :update_req} = handle), do: %{handle|state: :pack}
  def skip(%__MODULE__{state: :pack} = handle), do: %{handle|state: :done}
  def skip(%__MODULE__{state: :done} = handle), do: handle

  #
  # Helpers
  #

  defp report_status(cmds) do
    List.flatten(["unpack ok", Enum.map(cmds, &"ok #{elem(&1, :erlang.tuple_size(&1)-1)}"), :flush])
  end

  defp obj_match?({type, _oid}, type), do: true
  defp obj_match?(_line, _type), do: false

  defp parse_cmds(cmds) do
    Enum.map(cmds, fn cmd ->
      case String.split(cmd, " ", parts: 3) do
        [@null_oid, new, name] ->
          {:create, Git.oid_parse(new), name}
        [old, @null_oid, name] ->
          {:delete, Git.oid_parse(old), name}
        [old, new, name] ->
          {:update, Git.oid_parse(old), Git.oid_parse(new), name}
      end
    end)
  end

  defp parse_caps([]), do: {[], []}
  defp parse_caps([first_ref|refs]) do
    case String.split(first_ref, "\0", parts: 2) do
      [first_ref] -> {[], [first_ref|refs]}
      [first_ref, caps] -> {String.split(caps, " ", trim: true), [first_ref|refs]}
    end
  end

  defp apply_cmds(repo, cmds) do
    Enum.each(cmds, fn
      {:create, new_oid, refname} -> Git.reference_create(repo, refname, :oid, new_oid, false)
      {:update, _old_oid, new_oid, refname} -> Git.reference_create(repo, refname, :oid, new_oid, true)
      {:delete, _old_oid, refname} -> Git.reference_delete(repo, refname)
    end)
  end

  defp apply_pack(repo, pack) do
    {:ok, odb} = Git.repository_get_odb(repo)
    Enum.each(pack, &apply_pack_obj(odb, &1))
  end

  defp apply_pack_obj(odb, {:delta_reference, {base_oid, _base_obj_size, _result_obj_size, cmds}}) do
    {:ok, obj_type, obj_data} = Git.odb_read(odb, base_oid)
    new_data = apply_delta_chain(obj_data, "", cmds)
    {:ok, _oid} = apply_pack_obj(odb, {obj_type, new_data})
  end

  defp apply_pack_obj(odb, {obj_type, obj_data}) do
    {:ok, _oid} = Git.odb_write(odb, obj_data, obj_type)
  end

  defp apply_delta_chain(_source, target, []), do: target
  defp apply_delta_chain(source, target, [{:insert, chunk}|cmds]) do
    apply_delta_chain(source, target <> chunk, cmds)
  end

  defp apply_delta_chain(source, target, [{:copy, {offset, size}}|cmds]) do
    apply_delta_chain(source, target <> binary_part(source, offset, size), cmds)
  end
end
