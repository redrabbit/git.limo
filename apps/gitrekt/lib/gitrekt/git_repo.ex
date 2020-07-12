defprotocol GitRekt.GitRepo do
  @moduledoc """
  Protocol for implementing access to Git repositories.
  """

  @type t :: term

  @doc """
  Returns the agent for the given `repo`.
  """
  @spec get_agent(t) :: GitRekt.GitAgent.agent
  def get_agent(repo)
end
