defmodule GitGud.Web.EmailView do
  @moduledoc false
  use GitGud.Web, :view

  alias GitGud.Email

  import Phoenix.HTML.Tag

  @spec email_tags(Plug.Conn.t, Email.t) :: binary
  def email_tags(conn, email) do
    tags = []
    tags = if tag = verified_tag(conn, email), do: [tag|tags], else: tags
    content_tag(:div, [class: "field is-grouped is-grouped-multiline"], do:
      for tag <- Enum.reverse(tags) do
        content_tag(:div, [class: "control"], do: tag)
      end
    )
  end

  @spec title(atom, map) :: binary
  def title(:index, _assigns), do: "Emails"

  #
  # Helpers
  #

  defp verified_tag(_conn, %Email{verified: true}) do
    content_tag(:span, [class: "tag is-success"], do: "Verified")
  end

  defp verified_tag(conn, email) do
    form_for(conn, Routes.email_path(conn, :resend), [as: :email], &verified_tag_fields(&1, email))
  end

  defp verified_tag_fields(form, email) do
    [
      hidden_input(form, :id, value: email.id),
      content_tag(:div, [class: "tags has-addons"], do: [
        content_tag(:span, [class: "tag"], do: "Unverified"),
        submit("resend", class: "button tag is-link", style: "line-height:1rem")
      ])
    ]
  end
end
