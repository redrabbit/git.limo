defmodule GitGud.Web.ErrorView do
  @moduledoc """
  Module providing error views for most common errors.
  """

  use GitGud.Web, :view

  def render("400.json", %{details: details}) do
    %{errors: %{details: details}}
  end

  def render("400.json", _assigns) do
    %{errors: %{details: "Bad request"}}
  end

  def render("401.json", _assigns) do
    %{errors: %{details: "Unauthorized"}}
  end

  def render("404.json", _assigns) do
    %{errors: %{details: "Page not found"}}
  end

  def render("500.json", _assigns) do
    %{errors: %{details: "Internal server error"}}
  end

  def template_not_found(_template, assigns) do
    render "500.json", assigns
  end
end
