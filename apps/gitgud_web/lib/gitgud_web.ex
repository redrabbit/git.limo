defmodule GitGud.Web do
  @moduledoc """
  Module providing helper function for controllers, views, channels and so on.

  This can be used in your application as:

      use GitGud.Web, :controller
      use GitGud.Web, :view
  """

  @doc false
  def controller(opts) do
    quote do
      use Phoenix.Controller, unquote(Keyword.merge(opts, namespace: GitGud.Web))

      alias GitGud.Web.Router.Helpers, as: Routes

      import Plug.Conn

      import Phoenix.LiveView.Controller

      import GitGud.GraphQL.Schema, only: [from_relay_id: 1, to_relay_id: 1, to_relay_id: 2]

      import GitGud.Web.AuthenticationPlug, only: [
        authenticated?: 1,
        authorized?: 3,
        current_user: 1,
        ensure_authenticated: 2,
        verified?: 1
      ]

      import GitGud.Web.Gettext
      import GitGud.Web.PaginationHelpers, only: [
        paginate: 2,
        paginate: 3,
        paginate_cursor: 4,
        paginate_cursor: 5
      ]
    end
  end

  @doc false
  def view(opts) do
    quote do
      use Phoenix.View, unquote(Keyword.merge(opts, root: "lib/gitgud_web/templates", namespace: GitGud.Web))

      import Phoenix.Controller, only: [get_flash: 2, controller_module: 1, view_module: 1, action_name: 1]

      unquote(view_helpers())

      import GitGud.Web.AuthenticationPlug, only: [
        authenticated?: 1,
        authentication_token: 1,
        authorized?: 3,
        current_user: 1,
        ensure_authenticated: 2,
        verified?: 1
      ]

      import GitGud.Web.NavigationHelpers
      import GitGud.Web.PaginationHelpers
    end
  end

  @doc false
  def live_view(opts) do
    quote do
      use Phoenix.LiveView, unquote(opts)

      unquote(view_helpers())

      import GitGud.Web.AuthenticationLiveHelpers
    end
  end

  def live_component(_opts) do
    quote do
      use Phoenix.LiveComponent

      unquote(view_helpers())

      import GitGud.Web.AuthenticationLiveHelpers
    end
  end

  @doc false
  def router(_opts) do
    quote do
      use Phoenix.Router

      import Plug.Conn

      import Phoenix.Controller

      import Phoenix.LiveView.Router

      import GitGud.Web.AuthenticationPlug, only: [
        authenticate: 2,
        authenticate_bearer_token: 2,
        authenticate_session: 2
      ]
    end
  end

  @doc false
  def channel(opts) do
    quote do
      use Phoenix.Channel, unquote(opts)

      alias GitGud.Web.Presence
      alias GitGud.Web.Router.Helpers, as: Routes

      import GitGud.Web.Gettext
    end
  end

  @doc false
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [[]])
  end

  defmacro __using__({which, opts}) when is_atom(which) and is_list(opts) do
    apply(__MODULE__, which, [opts])
  end

  #
  # Helpers
  #

  defp view_helpers do
    quote do
      use Phoenix.HTML

      use GitGud.Web.FormHelpers

      alias GitGud.Web.Router.Helpers, as: Routes

      import Phoenix.View
      import Phoenix.LiveView.Helpers

      import GitGud.GraphQL.Schema, only: [to_relay_id: 1, to_relay_id: 2]

      import GitGud.Web.DateTimeFormatter
      import GitGud.Web.ErrorHelpers
      import GitGud.Web.Gettext
      import GitGud.Web.Gravatar
      import GitGud.Web.Markdown
      import GitGud.Web.ReactComponents
    end
  end
end
