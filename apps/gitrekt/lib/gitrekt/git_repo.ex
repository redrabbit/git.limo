defprotocol GitRekt.GitRepo do
  @moduledoc """
  Protocol for implementing access to Git repositories.
  """

  alias GitRekt.GitAgent
  alias GitRekt.WireProtocol.ReceivePack

  @type t :: term

  @doc """
  Returns the agent for the given `repo`.
  """
  @spec get_agent(t) :: {:ok, GitAgent.agent} | {:error, term}
  def get_agent(repo)

  @doc """
  Pushes the
  """
  @fallback_to_any true
  @spec push(t, [ReceivePack.cmd]) :: {:ok, t} | {:error, term}
  def push(repo, cmds)
end
