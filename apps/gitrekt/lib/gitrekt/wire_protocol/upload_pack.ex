defmodule GitRekt.WireProtocol.UploadPack do
  @moduledoc """
  Module implementing the `git-upload-pack` command.
  """

  @behaviour GitRekt.WireProtocol.Service

  alias GitRekt.Git

  import GitRekt.Packfile, only: [create: 2]
  import GitRekt.WireProtocol, only: [reference_discovery: 2]

  defstruct [:repo, state: :disco, caps: [], wants: [], haves: []]

  @type t :: %__MODULE__{
    repo: Git.repo,
    state: :disco | :upload_wants | :upload_haves | :done,
    caps: [binary],
    wants: [Git.oid],
    haves: [Git.oid],
  }

  #
  # Callbacks
  #

  @impl true
  def next(%__MODULE__{state: :disco} = handle, [:flush]) do
    {struct(handle, state: :done), []}
  end

  @impl true
  def next(%__MODULE__{state: :disco} = handle, lines) do
    {wants, lines} = Enum.split_while(lines, &obj_match?(&1, :want))
    {caps, wants} = parse_caps(wants)
    {_shallows, lines} = Enum.split_while(lines, &obj_match?(&1, :shallow))
    [:flush|lines] = lines
    {struct(handle, state: :upload_wants, caps: caps, wants: parse_cmds(wants)), lines}
  end

  @impl true
  def next(%__MODULE__{state: :upload_wants} = handle, [:done]) do
    {struct(handle, state: :done), []}
  end

  @impl true
  def next(%__MODULE__{state: :upload_wants} = handle, lines) do
    {:ok, odb} = Git.repository_get_odb(handle.repo)
    {haves, lines} = Enum.split_while(lines, &obj_match?(&1, :have))
    acks = Enum.filter(parse_cmds(haves), &Git.odb_object_exists?(odb, &1))
    case lines do
      [:flush|lines] ->
        {struct(handle, haves: [acks|handle.haves]), lines}
      [:done|lines] ->
        {struct(handle, state: :upload_haves, haves: [acks|handle.haves]), lines}
    end
  end

  @impl true
  def next(%__MODULE__{state: :upload_haves}, _lines), do: raise "Nothing should be run after :upload_haves"

  @impl true
  def next(%__MODULE__{state: :done}, _lines), do: raise "Cannot call next/2 when state == :done"

  @impl true
  def run(%__MODULE__{state: :disco} = handle) do
    {handle, reference_discovery(handle.repo, "git-upload-pack")}
  end

  @impl true
  def run(%__MODULE__{state: :upload_wants, haves: []} = handle) do
    {handle, []}
  end

  @impl true
  def run(%__MODULE__{state: :upload_wants} = handle) do
    acks = ack_haves(handle.haves, handle.caps)
    cond do
      "multi_ack_detailed" in handle.caps ->
        {handle, acks ++ [{:ack, List.last(List.last(handle.haves)), :ready}, :nak]}
      "multi_ack" in handle.caps ->
        {handle, acks ++ [:nak]}
      Enum.empty?(handle.haves) ->
        {handle, [:nak]}
      true ->
        {handle, Enum.take(acks, 5)}
    end
  end

  @impl true
  def run(%__MODULE__{state: :upload_haves} = handle) do
    {next, lines} = run(struct(handle, state: :done))
    cond do
      "multi_ack_detailed" in handle.caps ->
        {next, ack_haves(handle.haves, handle.caps) ++ lines}
      "multi_ack" in handle.caps ->
        {next, ack_haves(handle.haves, handle.caps) ++ lines}
      true ->
        {next, lines}
    end
  end

  @impl true
  def run(%__MODULE__{state: :done, wants: [], haves: []} = handle) do
    {handle, []}
  end

  def run(%__MODULE__{state: :done, haves: []} = handle) do
    {handle, [:nak, create(handle.repo, handle.wants)]}
  end

  def run(%__MODULE__{state: :done} = handle) do
    haves = List.flatten(Enum.reverse(handle.haves))
    pack = create(handle.repo, handle.wants ++ Enum.map(haves, &{&1, true}))
    cond do
      "multi_ack_detailed" in handle.caps ->
        {handle, [{:ack, List.last(haves)}, pack]}
      "multi_ack" in handle.caps ->
        {handle, [{:ack, List.last(haves)}, pack]}
      true ->
        {handle, [pack]}
    end
  end

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
  defp ack_haves([haves|_], caps) do
    cond do
      "multi_ack_detailed" in caps ->
        Enum.map(haves, &{:ack, &1, :common})
      "multi_ack" in caps ->
        Enum.map(haves, &{:ack, &1, :continue})
      true ->
        Enum.map(haves, &{:ack, &1})
    end
  end
end
