defprotocol GitRekt.GitRepo do
  @moduledoc """
  Protocol for implementing access to Git repositories.
  """

  @type t :: term

  @doc """
  Returns the agent for the given `repo`.
  """
  @spec get_agent(t) :: {:ok, GitRekt.GitAgent.agent} | {:error, term}
  def get_agent(repo)
end
