defmodule GitGud.Web.CommitDiffDynamicReviewsLive do
  @moduledoc false

  use GitGud.Web, :live_component

  import GitRekt.Git, only: [oid_fmt: 1]

  #
  # Callbacks
  #

  @impl true
  def mount(socket) do
    {:ok, assign(socket, reviews: []), temporary_assigns: [reviews: []]}
  end
end
