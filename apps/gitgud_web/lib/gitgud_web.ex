defmodule GitGud.Web do
  @moduledoc """
  Module providing helper function for controllers, views, channels and so on.

  This can be used in your application as:

      use GitGud.Web, :controller
      use GitGud.Web, :view
  """

  @doc false
  def controller do
    quote do
      use Phoenix.Controller, namespace: GitGud.Web

      alias GitGud.Web.Router.Helpers, as: Routes

      import Plug.Conn

      import GitGud.Authorization, only: [authorized?: 3]

      import GitGud.GraphQL.Schema, only: [from_relay_id: 1, to_relay_id: 1, to_relay_id: 2]

      import GitGud.Web.AuthenticationPlug, only: [authenticated?: 1, current_user: 1, ensure_authenticated: 2]
      import GitGud.Web.Gettext
    end
  end

  @doc false
  def view do
    quote do
      use Phoenix.View, root: "lib/gitgud_web/templates", namespace: GitGud.Web
      use Phoenix.HTML

      use GitGud.Web.FormValidation

      alias GitGud.Web.Router.Helpers, as: Routes

      import Phoenix.Controller, only: [get_flash: 2, controller_module: 1, view_module: 1, action_name: 1]

      import GitGud.Authorization, only: [authorized?: 3]
      import GitGud.GraphQL.Schema, only: [to_relay_id: 1, to_relay_id: 2]

      import GitGud.Web.AuthenticationPlug, only: [authenticated?: 1, authentication_token: 1, current_user: 1]

      import GitGud.Web.DateTimeFormatter
      import GitGud.Web.ErrorHelpers
      import GitGud.Web.Gettext
      import GitGud.Web.Gravatar
      import GitGud.Web.NavigationHelpers
      import GitGud.Web.PaginationHelpers
      import GitGud.Web.ReactComponents
    end
  end

  @doc false
  def router do
    quote do
      use Phoenix.Router

      import Plug.Conn
      import Phoenix.Controller

      import GitGud.Web.AuthenticationPlug, only: [authenticate: 2, authenticate_bearer_token: 2, authenticate_session: 2, ensure_authenticated: 2]
    end
  end

  @doc false
  def channel do
    quote do
      use Phoenix.Channel

      import GitGud.Web.Gettext
    end
  end

  @doc false
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
