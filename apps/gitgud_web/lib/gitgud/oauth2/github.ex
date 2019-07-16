defmodule GitGud.OAuth2.GitHub do
  @moduledoc """
  An *OAuth2.0* authentication strategy for GitHub.
  """
  use OAuth2.Strategy

  @doc """
  Returns a new *OAuth2.0* client.
  """
  @spec new() :: OAuth2.Client.t
  def new do
    Application.fetch_env!(:gitgud_web, __MODULE__)
    |> Keyword.merge(config())
    |> OAuth2.Client.new()
    |> OAuth2.Client.put_serializer("application/json", Jason)
  end

  #
  # Callbacks
  #

  @impl true
  def authorize_url(client, params) do
    OAuth2.Strategy.AuthCode.authorize_url(client, params)
  end

  @impl true
  def get_token(client, params, headers) do
    OAuth2.Strategy.AuthCode.get_token(client, params, headers)
  end

  #
  # Helpers
  #

  defp config do
    [strategy: __MODULE__,
     site: "https://api.github.com",
     authorize_url: "https://github.com/login/oauth/authorize",
     token_url: "https://github.com/login/oauth/access_token"]
  end
end
