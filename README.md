# Git Gud

A GitHub clone written in Elixir with almost no-dependencies.

* [x] Git HTTP and SSH support.
* [x] User authentication and permissions.
* [x] Fully integrated GraphQL API.
* [ ] Customizable Webhooks.
* [x] Native (NIF) implementation of Git commands.
* [ ] Customizable Git storage backend.
* [ ] Issue tracker, code review, continuous integration, ...

See the [Getting Started](http://almightycouch.com/gitgud/docs/getting-started.html) guide and the [online documentation](http://almightycouch.com/gitgud/docs).

## Install dependencies

First, ensure you have ~~Git and~~ [libgit2](https://libgit2.github.com) installed on your system:

#### OSX
```bash
brew install libgit2
```

#### Ubuntu
```bash
sudo apt-get install libgit2-dev
```

~~The former is necessary in temporarily because `git-upload-pack` and `git-receive-pack` server side commands use Erlang ports to execute the correspondent binaries. In future versions, those functions will be implemented natively and the dependency to Git will not be required anymore.~~

## Clone and compile

First, clone the latest version of the project:

```bash
git clone https://github.com/almightycouch/gitgud.git
```

Download Hex dependencies and compile everything:

```bash
mix deps.get
mix compile
```

## Generate SSH public keys

In order to provide SSH as a Git transport protocol, you must generate a valid SSH public key for the server:

```bash
ssh-keygen -t rsa -f apps/gitgud/priv/ssh-keys/ssh_host_rsa_key
```

## Setup database

The last step before running the server is to create and initialise the SQL database:

```bash
mix ecto.setup
```



## Run server

Finally, start both HTTP (port 4000) and SSH (port 8989) endpoints by running following command:

```bash
mix phx.server
```