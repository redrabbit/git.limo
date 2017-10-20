# Contributing

We love pull requests from everyone. Here's a quick guide:

Fork, then clone the repo:

    git clone git@github.com:your-username/gitgud.git

Run the tests. We only take pull requests with passing tests, and it's great to know that you have a clean state:

    mix do deps.get, compile, test

Make your change. Add tests for your change. After your changes are done, please remember to run the tests:

    mix test

Push to your fork and [submit a pull request][pr].

[pr]: https://github.com/almightycouch/gitgud/compare/

At this point you're waiting on us. We like to at least comment on pull requests
within three business days (and, typically, one business day). We may suggest
some changes or improvements or alternatives.

Some things that will increase the chance that your pull request is accepted:

* Write tests.
* Follow our [style guide][style].
* Write a [good commit message][commit].

[style]: http://elixir.community/styleguide
[commit]: https://github.com/erlang/otp/wiki/Writing-good-commit-messages
