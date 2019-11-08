defprotocol GitRekt.GitRepo do
  @moduledoc """
  Protocol for implementing access to Git repositories.
  """

  @doc """
  Returns the agent for the given `repo`.
  """
  def get_agent(repo)
end
