defmodule GitGud.Web.CommitLineReviewLive do
  @moduledoc """
  Live component responsible for rendering commit line reviews.
  """

  use GitGud.Web, :live_component

  alias GitGud.ReviewQuery

  #
  # Callbacks
  #

  @impl true
  def preload(list_of_assigns) do
    cond do
      Enum.all?(list_of_assigns, &Map.has_key?(&1, :comments)) ->
        list_of_assigns
      true ->
        %{repo: repo, commit: commit} = hd(list_of_assigns)
        comments = ReviewQuery.commit_line_reviews_comments(repo, commit, preload: :author)
        Enum.map(list_of_assigns, &Map.put_new(&1, :comments, comments[&1.review_id]))
    end
  end

  @impl true
  def mount(socket) do
    {:ok, socket, temporary_assigns: [comments: []]}
  end
end
