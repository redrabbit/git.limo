defmodule GitGud.Web.CommitDiffDynamicFormsLive do
  @moduledoc false

  use GitGud.Web, :live_component

  import GitRekt.Git, only: [oid_fmt: 1]

  #
  # Callbacks
  #

  @impl true
  def mount(socket) do
    {:ok, assign(socket, forms: []), temporary_assigns: [forms: []]}
  end
end
