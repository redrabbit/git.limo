defmodule GitRekt.WireProtocol.ReceivePack do
  @moduledoc """
  Module implementing the `git-receive-pack` command.
  """

  @behaviour GitRekt.WireProtocol.Service

  alias GitRekt.Git
  alias GitRekt.Packfile

  import GitRekt.WireProtocol, only: [reference_discovery: 2]

  @null_oid String.duplicate("0", 40)
  @null_iter {0, ""}

  defstruct [:repo, :callback, state: :disco, caps: [], cmds: [], pack: [], iter: @null_iter]

  @type callback :: {module, atom, [term]} | nil

  @type cmd :: {
    :create | :update | :delete,
    Git.oid,
    Git.oid,
  }

  @type t :: %__MODULE__{
    repo: Git.repo,
    callback: callback,
    state: :disco | :update_req | :pack | :buffer | :done,
    caps: [binary],
    cmds: [cmd],
    pack: Packfile.obj_list,
    iter: Packfile.obj_iter
  }

  @doc """
  Applies the given `receive_pack` *PACK* to the repository.
  """
  @spec apply_pack(t) :: {:ok, [Git.oid]} | {:error, term}
  def apply_pack(%__MODULE__{repo: repo, pack: pack} = _receive_pack) do
    case Git.repository_get_odb(repo) do
      {:ok, odb} -> {:ok, Enum.map(pack, &apply_pack_obj(odb, &1))}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Applies the given `receive_pack` commands to the repository.
  """
  @spec apply_cmds(t) :: :ok | {:error, term}
  def apply_cmds(%__MODULE__{repo: repo, cmds: cmds} = _receive_pack) do
    Enum.each(cmds, fn
      {:create, new_oid, name} ->
        :ok = Git.reference_create(repo, name, :oid, new_oid, false)
      {:update, _old_oid, new_oid, name} ->
        :ok = Git.reference_create(repo, name, :oid, new_oid, true)
      {:delete, _old_oid, name} ->
        :ok = Git.reference_delete(repo, name)
    end)
  end

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
    {read_pack(handle, lines), [], []}
  end

  @impl true
  def next(%__MODULE__{state: :buffer} = handle, pack) do
    {lines, ""} = Packfile.parse(pack, handle.iter)
    {%{handle|state: :pack}, lines, []}
  end

  @impl true
  def next(%__MODULE__{state: :done} = handle, []) do
    case odb_flush(handle) do
      :ok ->
        if "report-status" in handle.caps,
          do: {handle, [], report_status(handle.cmds)},
        else: {handle, [], []}
    end
  end

  @impl true
  def skip(%__MODULE__{state: :disco} = handle), do: %{handle|state: :update_req}
  def skip(%__MODULE__{state: :update_req} = handle), do: %{handle|state: :pack}
  def skip(%__MODULE__{state: :pack} = handle), do: %{handle|state: :done}
  def skip(%__MODULE__{state: :done} = handle), do: handle

  #
  # Helpers
  #

  defp odb_flush(%__MODULE__{callback: nil} = handle) do
    case apply_pack(handle) do
      {:ok, _oids} -> apply_cmds(handle)
      {:error, reason} -> {:error, reason}
    end
  end

  defp odb_flush(%__MODULE__{callback: callback} = handle) do
    {module, fun, args} = callback
    apply(module, fun, args ++ [handle])
  end

  defp report_status(cmds) do
    List.flatten(["unpack ok", Enum.map(cmds, &"ok #{elem(&1, :erlang.tuple_size(&1)-1)}"), :flush])
  end

  defp read_pack(handle, [{:buffer, pack, iter}]), do: %{handle|state: :buffer, pack: handle.pack ++ pack, iter: iter}
  defp read_pack(handle, pack) when is_list(pack), do: %{handle|state: :done, pack: handle.pack ++ pack, iter: @null_iter}

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

  defp obj_match?({type, _oid}, type), do: true
  defp obj_match?(_line, _type), do: false

  defp apply_pack_obj(odb, {:delta_reference, {base_oid, base_obj_size, result_obj_size, cmds}}) do
    {:ok, obj_type, obj_data} = Git.odb_read(odb, base_oid)
    if base_obj_size != byte_size(obj_data),
      do: raise ArgumentError, message: "invalid base PACK object size (#{base_obj_size} != #{byte_size(obj_data)})"
    new_data = resolve_delta_chain(obj_data, "", cmds)
      if result_obj_size != byte_size(new_data),
        do: raise ArgumentError, message: "invalid result PACK object size (#{result_obj_size} != #{byte_size(new_data)})"
    apply_pack_obj(odb, {obj_type, new_data})
  end

  defp apply_pack_obj(odb, {obj_type, obj_data}) do
    case Git.odb_write(odb, obj_data, obj_type) do
      {:ok, oid} -> oid
      {:error, reason} -> raise ArgumentError, message: reason
    end
  end

  defp resolve_delta_chain(_source, target, []), do: target
  defp resolve_delta_chain(source, target, [{:insert, chunk}|cmds]) do
    resolve_delta_chain(source, target <> chunk, cmds)
  end

  defp resolve_delta_chain(source, target, [{:copy, {offset, size}}|cmds]) do
    resolve_delta_chain(source, target <> binary_part(source, offset, size), cmds)
  end
end
