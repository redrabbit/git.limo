# Git Gud / Git Rekt

A GitHub clone written in Elixir with almost no-dependencies.

The basic idea is to build a lightweight and customisable Git server on top of [`libgit2`](https://libgit2.github.com):

* Git related commands available through `libgit2`.
* Native HTTPS and SSH Git server implementation.
* Pluggable `libgit2` backend for storing Git data into KV-Store such as *RocksDB*, *Riak* or *CouchDB*.


## Scalability

Having the possibility to use our own Git implementation without relying on `git` commands and hooks on the server would provide a lot of advantages in order to scale out the platform.

Using a custom `libgit2` backend such as *Riak* means that we can handle Git related data (repositories) in a distributed environment.

Native support of Git protocols such as *HTTP* and *SSH* offers fine-grain control over authentication and authorisation that would be tedious to setup otherwise.




