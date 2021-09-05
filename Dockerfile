ARG ELIXIR_VERSION=1.14.1
ARG ERLANG_VERSION=24.3.4.3
ARG ALPINE_VERSION=3.14.6
ARG LINUX_VERSION=alpine-$ALPINE_VERSION

FROM hexpm/elixir:$ELIXIR_VERSION-erlang-$ERLANG_VERSION-$LINUX_VERSION as build

ENV MIX_ENV=prod

WORKDIR /build

RUN apk add --no-cache build-base erlang-dev libgit2-dev git nodejs yarn && \
    mix local.hex --force && \
    mix local.rebar --force

COPY mix.exs mix.lock ./
COPY apps/gitrekt/mix.exs apps/gitrekt/
COPY apps/gitgud/mix.exs apps/gitgud/
COPY apps/gitgud_web/mix.exs apps/gitgud_web/

RUN mix do deps.get --only prod, deps.compile --skip-umbrella-children

COPY apps/gitrekt/Makefile apps/gitrekt/
COPY apps/gitrekt/c_src apps/gitrekt/c_src
COPY apps/gitrekt/config apps/gitrekt/config
COPY apps/gitrekt/lib apps/gitrekt/lib

COPY apps/gitgud/config  apps/gitgud/config
COPY apps/gitgud/lib apps/gitgud/lib
COPY apps/gitgud/priv apps/gitgud/priv

COPY apps/gitgud_web/config apps/gitgud_web/config
COPY apps/gitgud_web/lib apps/gitgud_web/lib
COPY apps/gitgud_web/priv/ apps/gitgud_web/priv

COPY config ./config

RUN mix compile

COPY apps/gitgud_web/assets/ apps/gitgud_web/assets

RUN yarn --cwd apps/gitgud_web/assets install --pure-lockfile && \
    yarn --cwd apps/gitgud_web/assets build --deploy

RUN mix phx.digest /build/apps/gitgud_web/priv/static

COPY rel ./rel

RUN mix release

FROM hexpm/elixir:$ELIXIR_VERSION-erlang-$ERLANG_VERSION-$LINUX_VERSION as app

RUN apk add --no-cache libgit2 openssl openssh-keygen ncurses-libs

WORKDIR /app

RUN chown nobody:nobody /app

COPY --from=build --chown=nobody:nobody /build/_build/prod/rel/git_limo ./
COPY entrypoint.sh ./

RUN mkdir ssh-keys
RUN yes y | ssh-keygen -m PEM -t rsa -N "" -f ssh-keys/ssh_host_rsa_key

EXPOSE 4000
EXPOSE 1022

ARG APP_REVISION
ENV APP_REVISION=$APP_REVISION

ENTRYPOINT ["./entrypoint.sh"]
CMD ["bin/git_limo", "start"]
