FROM centos:centos8

ARG SRC_DIR="/var/lib/gitgud"

RUN rpm -ivh https://packages.erlang-solutions.com/erlang-solutions-2.0-1.noarch.rpm && \
    dnf update -y && \
    dnf group install -y --setopt=group_package_types=mandatory 'Development Tools' && \
    dnf config-manager --set-enabled PowerTools && \
    dnf module enable -y nodejs:12 && \
    dnf install -y elixir erlang-parsetools erlang-sasl erlang-ssh glibc-langpack-en libgit2-devel nodejs && \
    mix local.rebar --force && \
    mix local.hex --force

ADD gitgud-latest.tar.gz ${SRC_DIR}
ADD https://gist.githubusercontent.com/redrabbit/26e6da059c0780e7da06c9db0683bae9/raw/75de6fd2410ae5261cc02ebae21123095977e0c0/releases.exs ${SRC_DIR}/config/releases.exs

ENV MIX_ENV=prod

WORKDIR ${SRC_DIR}
RUN mix deps.get --only prod && \
    mix deps.compile

WORKDIR ${SRC_DIR}/apps/gitgud_web/assets
RUN npm i && \
    npm run deploy

WORKDIR ${SRC_DIR}/apps/gitgud_web
RUN mix phx.digest

WORKDIR ${SRC_DIR}
RUN mix release
