########################################
## Functions

# Check that a required environment variable is defined
define check_env_var
	@if [ -z "$($(1))" ]; then echo "Error: $(1) env var is not defined" >&2; exit 1; fi
endef

########################################
## Configuration

# Current OCaml version
OCAML_VERSION = "4.14.2"

# machine word size
WORD_SIZE = "64"

# Default profile
ifeq ($(DUNE_PROFILE),)
DUNE_PROFILE := dev
endif

########################################
## Branch and versioning
# Default branch name
# This is used for versioning and release purposes when building docker or debian
# For example when BRANCH_NAME=fix-branch:
# Target version : 3.1.2-alpha-fix-branch-bullseye-devnet
BRANCH_NAME ?= $(shell git rev-parse --abbrev-ref HEAD)

ifeq ($(OPAMSWITCH)$(IN_NIX_SHELL)$(CI)$(BUILDKITE),)
# Sometimes opam replaces these env variables in shell with
# an explicit mention of a particular switch (dereferenced from the value)
OPAM_SWITCH_PREFIX := $(PWD)/_opam
OCAML_TOPLEVEL_PATH := $(OPAM_SWITCH_PREFIX)/lib/toplevel
PATH := $(OPAM_SWITCH_PREFIX)/bin:$(PATH)
endif

# Temp directory
TMPDIR ?= /tmp

# Genesis dir
GENESIS_DIR := $(TMPDIR)/coda_cache_dir

# Coverage directory
COVERAGE_DIR=_coverage

########################################
## Handy variables

# Distribution codename, to be used in Docker builds
CODENAME ?= $(shell lsb_release -cs)

# Network for the aggregate local build targets (debian-build-all / docker-build-all).
# devnet or mainnet.
NETWORK ?= devnet

# Set LOAD_ONLY=1 for purely local docker builds: images are loaded into the
# local docker daemon only and NOT pushed to the (o1labs) registry. Leave unset
# to preserve the historical push behaviour of build_docker_image.
ifeq ($(LOAD_ONLY),1)
DOCKER_LOAD_ONLY_ARG := --load-only
else
DOCKER_LOAD_ONLY_ARG :=
endif

# Individual docker-build-* targets build from scratch, preserving their
# historical behaviour. docker-build-all overrides this to empty: it builds
# mina-base, archive and daemon back-to-back off the SAME base-deps layer, so
# --no-cache would re-run that layer's apt update/upgrade and gcloud SDK
# download three times in one invocation.
DOCKER_NO_CACHE ?= --no-cache

# This commit hash
GITHASH := $(shell git rev-parse --short=8 HEAD)
GITLONGHASH := $(shell git rev-parse HEAD)

# Unique signature of libp2p code tree
LIBP2P_HELPER_SIG := $(shell cd src/app/libp2p_helper ; find . -type f -print0  | xargs -0 sha1sum | sort | sha1sum | cut -f 1 -d ' ')

# Database for archive
PG_USER ?= mina
PG_PW 	?= minaminamina
PG_DB 	?= archive
PG_HOST	?= localhost
PG_PORT	?= 5432

