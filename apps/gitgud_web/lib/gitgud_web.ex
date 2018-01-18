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
      import Plug.Conn
      import GitGud.Web.Router.Helpers
      import GitGud.Web.Gettext
      import GitGud.Web.AuthenticationPlug, only: [authenticated?: 1, ensure_authenticated: 2]
    end
  end

  @doc false
  def view do
    quote do
      use Phoenix.View, root: "lib/gitgud_web/templates",
                        namespace: GitGud.Web

      # Import convenience functions from controllers
      import Phoenix.Controller, only: [get_flash: 2, view_module: 1]

      # Use all HTML functionality (forms, tags, etc)
      use Phoenix.HTML

      import GitGud.Web.Router.Helpers
      import GitGud.Web.ErrorHelpers
      import GitGud.Web.Gettext
      import GitGud.Web.AuthenticationPlug, only: [authenticated?: 1]
    end
  end

  @doc false
  def router do
    quote do
      use Phoenix.Router
      import Plug.Conn
      import Phoenix.Controller

      alias GitGud.Web.AuthenticationPlug
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
