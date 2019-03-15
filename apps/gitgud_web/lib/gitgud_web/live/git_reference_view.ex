defmodule GitGud.Web.GitReferenceView do
  use Phoenix.LiveView

  alias GitGud.Repo
  alias GitGud.GitReference

  alias GitGud.Web.Router.Helpers, as: Routes

  def render(assigns) do
    ~L"""
      <div class="dropdown<%= if @active, do: " is-active" %> branch-select">
        <div class="dropdown-trigger">
          <button class="button" aria-haspopup="true" aria-controls="dropdown-menu" phx-click="toggle_dropdown">
            <span>Branch: <span class="has-text-weight-semibold"><%= @revision.name %></span></span>
            <span class="icon is-small">
              <i class="fas fa-angle-down" aria-hidden="true"></i>
            </span>
          </button>
        </div>
        <div class="dropdown-menu" id="dropdown-menu" role="menu">
          <nav class="panel">
            <div class="panel-heading">
              <p class="control has-icons-left">
                <input class="input is-small" type="text" placeholder="Filter ..." />
                <span class="icon is-small is-left">
                  <i class="fa fa-filter" aria-hidden="true"></i>
                </span>
              </p>
            </div>
            <p class="panel-tabs">
              <a class="<%= if @type == :branch, do: "is-active" %>" phx-click="toggle_tab" phx-value="branch">Branches</a>
              <a class="<%= if @type == :tag, do: "is-active" %>" phx-click="toggle_tab" phx-value="tag">Tags</a>
            </p>
            <%= for ref <- Enum.filter(@references, &(&1.type == @type)) do %>
              <a href="<%= Routes.codebase_path(@socket, :tree, @repo.owner, @repo, ref.name, []) %>" class="panel-block"><%= ref.name %></a>
            <% end %>
          </nav>
        </div>
      </div>
    """
  end

  def mount(%{repo: repo, revision: revision}, socket) do
    repo = struct(repo, __git__: nil)
    repo = Repo.open(repo)
    {:ok, references} = GitGud.Repo.git_references(repo)
    socket = assign(socket, :active, false)
    socket = assign(socket, :repo, repo)
    socket = assign(socket, :type, revision.type)
    socket = assign(socket, :revision, revision)
    socket = assign(socket, :references, references)
    {:ok, socket}
  end

  def handle_event("toggle_dropdown", _value, socket) do
    {:noreply, assign(socket, :active, !socket.assigns.active)}
  end

  def handle_event("toggle_tab", "branch", socket) do
    {:noreply, assign(socket, :type, :branch)}
  end

  def handle_event("toggle_tab", "tag", socket) do
    {:noreply, assign(socket, :type, :tag)}
  end
end
