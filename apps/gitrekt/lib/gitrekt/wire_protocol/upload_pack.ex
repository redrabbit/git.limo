defmodule GitRekt.WireProtocol.UploadPack do
  @moduledoc """
  Module implementing the `git-upload-pack` command.
  """

  @behaviour GitRekt.WireProtocol

  alias GitRekt.Git
  alias GitRekt.GitAgent

  import GitRekt.WireProtocol, only: [reference_discovery: 3]

  @service_name "git-upload-pack"

  defstruct [:agent, state: :disco, caps: [], wants: [], haves: []]

  @type t :: %__MODULE__{
    agent: GitAgent.agent,
    state: :disco | :upload_req | :upload_haves | :pack | :done,
    caps: [binary],
    wants: [Git.oid],
    haves: [Git.oid],
  }

  #
  # Callbacks
  #

  @impl true
  def next(%__MODULE__{state: :disco} = handle, [:flush|lines]) do
    {%{handle|state: :done, caps: []}, lines, reference_discovery(handle.agent, @service_name, handle.caps)}
  end

  def next(%__MODULE__{state: :disco} = handle, lines) do
    {%{handle|state: :upload_req, caps: []}, lines, reference_discovery(handle.agent, @service_name, handle.caps)}
  end

  def next(%__MODULE__{state: :upload_req} = handle, [:flush|lines]) do
    {%{handle|state: :done}, lines, []}
  end

  def next(%__MODULE__{state: :upload_req} = handle, lines) do
    {wants, lines} = Enum.split_while(lines, &obj_match?(&1, :want))
    {caps, wants} = parse_caps(wants)
    {_shallows, lines} = Enum.split_while(lines, &obj_match?(&1, :shallow))
    [:flush|lines] = lines
    {%{handle|state: :upload_haves, caps: caps, wants: parse_cmds(wants)}, lines, []}
  end

  def next(%__MODULE__{state: :upload_haves} = handle, []) do
    {%{handle|state: :done}, [], []}
  end

  def next(%__MODULE__{state: :upload_haves} = handle, [:flush|lines]) do
    {handle, lines, ack_haves(handle.haves, handle.caps) ++ [:nak]}
  end

  def next(%__MODULE__{state: :upload_haves} = handle, [:done|lines]) do
    next(%{handle|state: :pack}, lines)
  end

  def next(%__MODULE__{state: :upload_haves} = handle, lines) do
    {:ok, odb} = GitAgent.odb(handle.agent)
    {haves, lines} = Enum.split_while(lines, &obj_match?(&1, :have))
    haves =
      Enum.filter(parse_cmds(haves), fn have ->
        case GitAgent.odb_object_exists?(handle.agent, odb, have) do
          {:ok, exists?} -> exists?
          {:error, reason} -> raise reason
        end
      end)
    {%{handle|haves: haves}, lines, []}
  end

  def next(%__MODULE__{state: :pack} = handle, []) do
    if Enum.empty?(handle.haves) do
      {:ok, pack} = GitAgent.pack_create(handle.agent, handle.wants, timeout: :infinity)
      {%{handle|state: :done}, [], [:nak, pack]}
    else
      haves = List.flatten(Enum.reverse(handle.haves))
      {:ok, pack} = GitAgent.pack_create(handle.agent, handle.wants ++ Enum.map(haves, &{&1, true}), timeout: :infinity)
      cond do
        "multi_ack" in handle.caps ->
          {%{handle|state: :done}, [], [{:ack, List.first(haves)}, pack]}
        "multi_ack_detailed" in handle.caps ->
          {%{handle|state: :done}, [], [{:ack, List.first(haves)}, pack]}
        true ->
          {%{handle|state: :done}, [], [:nak, pack]}
      end
    end
  end

  def next(%__MODULE__{state: :done} = handle, []) do
    {handle, [], []}
  end

  @impl true
  def skip(%__MODULE__{state: :disco} = handle), do: %{handle|state: :upload_req, caps: []}
  def skip(%__MODULE__{state: :upload_req} = handle), do: %{handle|state: :upload_haves}
  def skip(%__MODULE__{state: :upload_haves} = handle), do: %{handle|state: :pack}
  def skip(%__MODULE__{state: :pack} = handle), do: %{handle|state: :done}
  def skip(%__MODULE__{state: :done} = handle), do: handle

  #
  # Helpers
  #

  defp obj_match?({type, _oid}, type), do: true
  defp obj_match?(_line, _type), do: false

  defp parse_cmds(cmds), do: Enum.uniq(Enum.map(cmds, &Git.oid_parse(elem(&1, 1))))

  defp parse_caps([]), do: {[], []}
  defp parse_caps([{obj_type, first_ref}|wants]) do
    case String.split(first_ref, " ", parts: 2) do
      [first_ref]       -> {[], [{obj_type, first_ref}|wants]}
      [first_ref, caps] -> {String.split(caps, " ", trim: true), [{obj_type, first_ref}|wants]}
    end
  end

  defp ack_haves([], _caps), do: []
  defp ack_haves(haves, caps) do
    cond do
      "multi_ack" in caps ->
        Enum.map(haves, &{:ack, &1, :continue})
      "multi_ack_detailed" in caps ->
        Enum.map(haves, &{:ack, &1, :common})
      true ->
        Enum.map(haves, &{:ack, &1})
    end
  end
end
