defmodule GitGud.Web.IssueLabelView do
  @moduledoc false
  use GitGud.Web, :view

  def label_button(label) do
    threshold = 130
    label_text_class = if color_brighness(label.color) > threshold, do: "has-text-dark", else: "has-text-light"
    content_tag(:button, label.name, class: "button issue-label #{label_text_class} is-active", style: "background-color: ##{label.color}")
  end

  def color_picker(label) do
    threshold = 130
    label_text_class = if color_brighness(label.color) > threshold, do: "has-text-dark", else: "has-text-light"
    content_tag(:a, "#" <> label.color, class: "button pickr is-hidden #{label_text_class}", style: "background-color: ##{label.color}")
  end

  @spec title(atom, map) :: binary
  def title(:index, %{repo: repo}), do: "Issues labels · #{repo.owner.login}/#{repo.name}"

  #
  # Helpers
  #

  defp color_brighness(<<r::binary-size(2), g::binary-size(2), b::binary-size(2)>>) do
    div((String.to_integer(r, 16) * 299) + (String.to_integer(g, 16) * 587) + (String.to_integer(b, 16) * 114), 1_000)
  end
end
