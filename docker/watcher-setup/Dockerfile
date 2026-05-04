FROM ubuntu:24.04

ARG GHC_VERSION=9.12.2
ARG CABAL_VERSION=3.14.2.0

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH=/root/.ghcup/bin:/root/.cabal/bin:$PATH

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    bash \
    build-essential \
    ca-certificates \
    coreutils \
    curl \
    git \
    gnupg \
    jq \
    libffi-dev \
    libgmp-dev \
    lsb-release \
    netcat-openbsd \
    pkg-config \
    python3 \
    xz-utils \
    zlib1g-dev \
  && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/apt/keyrings \
  && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | gpg --dearmor -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
  && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends gh \
  && rm -rf /var/lib/apt/lists/*

RUN curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org \
    | BOOTSTRAP_HASKELL_NONINTERACTIVE=1 BOOTSTRAP_HASKELL_MINIMAL=1 sh \
  && ghcup install ghc "$GHC_VERSION" \
  && ghcup set ghc "$GHC_VERSION" \
  && ghcup install cabal "$CABAL_VERSION" \
  && ghcup set cabal "$CABAL_VERSION"

WORKDIR /work/moifold
