defmodule GitGud.Web.UserEmailView do
  @moduledoc false
  use GitGud.Web, :view

  alias GitGud.UserEmail

  import Phoenix.HTML.Link
  import Phoenix.HTML.Tag

  @spec email_tags(Plug.Conn.t, UserEmail.t) :: binary
  def email_tags(conn, email) do
    tags = []
    tags = if tag = unverified_tag(conn, email), do: [tag|tags], else: tags

    content_tag(:div, [class: "field is-grouped is-grouped-multiline"], do:
      for tag <- tags do
        content_tag(:div, [class: "control"], do: tag)
      end
    )
  end

  @spec title(atom, map) :: binary
  def title(:index, _assigns), do: "Emails"
  def title(:new, _assigns), do: "Add a new email"

  #
  # Helpers
  #

  defp unverified_tag(_conn, %UserEmail{verified: true}), do: nil
  defp unverified_tag(conn, _user_email) do
    content_tag(:div, [class: "tags has-addons"], do: [
      content_tag(:span, [class: "tag"], do: "Unverified"),
      link("resend", to: Routes.user_email_path(conn, :index), class: "tag is-link")
    ])
  end
end

