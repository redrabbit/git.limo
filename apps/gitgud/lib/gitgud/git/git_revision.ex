defprotocol GitGud.GitRevision do
  @moduledoc """
  Protocol for implementing Git revision functionalities.
  """

  @doc """
  Returns the commit history starting from the given `revision`.
  """
  def history(revision)

  @doc """
  Returns the tree of the given `revision`.
  """
  def tree(revision)
end
