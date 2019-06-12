# Getting Started

This guide is an introduction to [GitGud](https://github.com/almightycouch/gitgud), a Git repository web service written in Elixir.

GitGud is an umbrella application split into three main components:

* `GitRekt` - Low-level Git functionalities written in C available as NIFs (see `GitRekt.Git`). It also provides native support for Git [transfer protocols]() and [PACK format]().
* `GitGud` - Defines database schemas such as `GitGud.User` and `GitGud.Repo` and provides building-blocks for authentication, authorization, Git SSH and HTTP [transport protocols](), etc.
* `GitGud.Web` - Web-frontend similar to the one offered by [GitHub](https://github.com) providing a user-friendly management tool for Git repositories. It also features a [GraphQL API]().

In the following sections, we will provide an overview of those components and how they interact with each other. Feel free to access their respective module documentation for more specific examples, options and configuration.
