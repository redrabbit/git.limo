defprotocol GitRekt.GitRepo do
  @moduledoc """
  Protocol for implementing access to Git repositories.
  """

  @doc """
  Returns the agent for the given `repo`.
  """
  def get_agent(repo)

  @doc """
  Puts the agent to the given `repo`.
  """
  def put_agent(repo, mode)
end
