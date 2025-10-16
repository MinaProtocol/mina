FROM ruby:3.4.6-slim-trixie

# Preinstalled system package
# 1. build-essential is needed by ruby native extention
# 2. docker is needed to run containerized tests
# 3. git is needed by bundler
# 4. libyaml-dev is needed for gem `psych`

RUN apt-get update --yes \
  && apt-get install --yes --no-install-recommends \
    build-essential \
    docker \
    git \
    libyaml-dev \
  && rm -rf /var/lib/apt/lists/*
