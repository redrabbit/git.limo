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
  def next(%__MODULE__{state: :upload_wants} = handle, lines) do
    {haves, lines} = Enum.split_while(lines, &obj_match?(&1, :have))
    {struct(handle, state: :upload_haves, haves: parse_cmds(haves)), lines}
  end

  @impl true
  def next(%__MODULE__{state: :upload_haves} = handle, [:done]) do
    {handle, []}
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
  def run(%__MODULE__{state: :upload_wants} = handle) do
    {handle, []}
  end

  @impl true
  def run(%__MODULE__{state: :upload_haves} = handle) do
    {struct(handle, state: :done), [:nak, create(handle.repo, handle.wants)]}
  end

  @impl true
  def run(%__MODULE__{state: :done} = handle) do
    {handle, []}
  end

  #
  # Helpers
  #

  defp obj_match?({type, _oid}, type), do: true
  defp obj_match?(_line, _type), do: false

  defp parse_cmds(cmds), do: Enum.uniq(Enum.map(cmds, &Git.oid_parse(elem(&1, 1))))

  defp parse_caps([]), do: {[], []}
  defp parse_caps([{obj_type, first_ref}|wants]) do
    case String.split(first_ref, "\0", parts: 2) do
      [first_ref]       -> {[], [{obj_type, first_ref}|wants]}
      [first_ref, caps] -> {String.split(caps, " ", trim: true), [{obj_type, first_ref}|wants]}
    end
  end
end
