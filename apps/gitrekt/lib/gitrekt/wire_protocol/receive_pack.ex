defmodule GitRekt.WireProtocol.ReceivePack do
  @moduledoc """
  """

  import GitRekt.WireProtocol, only: [reference_discovery: 2]

  alias GitRekt.Git
  alias GitRekt.Packfile

  defstruct [:repo, state: :disco, caps: [], cmds: [], pack: []]

  @type state :: :disco | :update_req | :pack | :done
  @type command :: :create | :update | :delete

  @type update_command :: {command, Git.oid, Git.oid, binary}
  @type update_list :: [update_command]

  @type t :: %__MODULE__{
    state: state,
    repo: Git.repo,
    caps: [binary],
    cmds: update_list,
    pack: Packfile.obj_list
  }

  @spec next(t, [term]) :: {t, [term]}
  def next(%__MODULE__{state: :disco} = handle, [:flush] = _lines) do
    {struct(handle, state: :done), []}
  end

  def next(%__MODULE__{state: :disco} = handle, lines) do
    {_shallows, lines} = Enum.split_while(lines, &obj_match?(&1, :shallow))
    {cmds, lines} = Enum.split_while(lines, &is_binary/1)
    {caps, cmds} = parse_caps(cmds)
    [:flush|lines] = lines
    {struct(handle, state: :update_req, caps: caps, cmds: parse_cmds(cmds)), lines}
  end

  def next(%__MODULE__{state: :update_req} = handle, lines) do
    {struct(handle, state: :pack, pack: lines), []}
  end

  def next(%__MODULE__{state: :pack} = handle, []) do
    {handle, []}
  end

  def next(%__MODULE__{state: :pack}, _lines), do: raise "Nothing should be run after :pack"
  def next(%__MODULE__{state: :done}, _lines), do: raise "Cannot call next/2 when state == :done"

  @spec run(t) :: {t, [binary]}
  def run(%__MODULE__{state: :disco} = handle) do
    {handle, reference_discovery(handle.repo, "git-receive-pack")}
  end

  def run(%__MODULE__{state: :update_req} = handle) do
    {handle, []}
  end

  def run(%__MODULE__{state: :pack} = handle) do
    :ok = apply_pack(handle.repo, handle.pack)
    :ok = apply_cmds(handle.repo, handle.cmds)
    handle = struct(handle, state: :done)
    if "report-status" in handle.caps,
      do: {handle, report_status(handle.cmds)},
    else: {handle, []}
  end

  def run(%__MODULE__{state: :done} = handle) do
    {handle, []}
  end

  #
  # Helpers
  #

  defp report_status(cmds) do
    List.flatten(["unpack ok", Enum.map(cmds, &"ok #{elem(&1, 3)}"), :flush])
  end

  defp obj_match?({type, _oid}, type), do: true
  defp obj_match?(_line, _type), do: false

  defp parse_cmds(cmds) do
    Enum.map(cmds, fn cmd ->
      case String.split(cmd) do
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
      {:update, _old_oid, new_oid, refname} -> Git.reference_create(repo, refname, :oid, new_oid, true)
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
