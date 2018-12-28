# Getting Started

This guide is an introduction to [GitGud](https://github.com/almightycouch/gitgud), a Git repository web service written in Elixir.

GitGud is an umbrella application split into three main components:

* `GitRekt` - Low-level Git functionalities written in C available as NIFs (see `GitRekt.Git`). It also provides native support for Git [transfer protocols]() and [PACK format]().
* `GitGud` - Defines database schemas such as `GitGud.User` and `GitGud.Repo` and provides building-blocks for authentication, authorization, Git SSH and HTTP [transport protocols](), etc.
* `GitGud.Web` - Web-frontend similar to the one offered by [GitHub](https://github.com) providing a user-friendly management tool for Git repositories. It also features a [GraphQL API]().

In the following sections, we will provide an overview of those components and how they interact with each other. Feel free to access their respective module documentation for more specific examples, options and configuration.

## Working with Git

`GitRekt.Git` exposes a subset of [libgit2](https://libgit2.org) functions and offers a fast API for manipulating Git objects.

Let's see a brief example:

```elixir
alias GitRekt.Git

# load repository
{:ok, repo} = Git.repository_open("/tmp/my-repo")

# show last commit of branch "master"
{:ok, :commit, oid, commit} = Git.reference_peel(repo, "refs/heads/master")
{:ok, name, email, time, _offset} = Git.commit_author(commit)
{:ok, message} = Git.commit_message(commit)

IO.puts "Last commit by #{name} <#{email}>:"
IO.puts message
```

In this example, each Git related function is implemented in C instead of Elixir.

These functions are compiled and linked into a dynamic loadable, shared library. They belong to a module and are called like any other Elixir functions.

> As a NIF library is dynamically linked into the emulator process, this is the fastest way of calling C-code from Erlang (alongside port drivers). Calling NIFs requires no context switches. But it is also the least safe, because a crash in a NIF brings the emulator down too.
>
> [Erlang documentation - NIFs](http://erlang.org/doc/tutorial/nif.html)

Altough in the example above we have directly called low-level Git functions to query Git related objects, most of the time `GitGud.Repo` provides a better entry-point to work with Git repositories.

Let's rewrite the last example using the higher-level `GitGud.Repo` API.

```elixir
alias GitGud.{Repo, RepoQuery, GitReference, GitCommit}

# load repository
repo = RepoQuery.user_repo("redrabbit", "gitgud")
repo = Repo.open(repo)

# show last commit of branch "master"
{:ok, head} = Repo.git_branch(repo, "master")
{:ok, commit} = GitReference.target(head)
{:ok, author} = GitCommit.author(commit)
{:ok, message} = GitCommit.message(commit)

IO.puts "Last commit by #{author.name} <#{author.email}>:"
IO.puts message
```

Here's a slightly more complex example displaying the last 10 commits:

```elixir
alias GitGud.{Repo, RepoQuery, GitCommit}

# load repository
repo = RepoQuery.user_repo("redrabbit", "gitgud")
repo = Repo.open(repo)

# show last 10 commits
{:ok, head} = Repo.git_head(repo)
{:ok, stream} = Repo.git_history(head)
for commit <- Enum.take(stream, 10) do
	{:ok, author} = GitCommit.author(commit)
	{:ok, message} = GitCommit.message(commit)
	IO.puts "Commit by #{author.name} <#{author.email}>:"
	IO.puts message
end
```
