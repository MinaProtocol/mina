#!/bin/sh

O1LABS=https://github.com/o1-labs
MINA=https://github.com/MinaProtocol
OBAZL=https://github.com/obazl

BRANCH=master
MINA_BRANCH=mina-bazel
ROCKS_BRANCH=mina

# Assumption: we're running this from the PARENT of the mina root dir
cd mina && git checkout ${MINA_BRANCH}  && git pull && git submodule init && git submodule update --init --recursive && cd -;

####
git clone ${O1LABS}/graphql_ppx.git && cd graphql_ppx && git checkout ${BRANCH} && git pull && cd ..;

git clone ${O1LABS}/ppx_version.git && cd ppx_version && git checkout ${BRANCH} && git pull && cd -;

git clone ${O1LABS}/snarky.git && cd snarky && git checkout ${BRANCH} && git pull && cd -;

git clone ${O1LABS}/marlin.git && cd marlin && git checkout ${BRANCH} && git pull && cd -;

git clone ${O1LABS}/zexe.git && cd zexe && git checkout ${BRANCH} & git pull && cd -;

####
git clone ${MINA}/async_kernel.git && cd async_kernel && git checkout ${BRANCH} && git pull && cd -;

git clone ${MINA}/ocaml-extlib.git && cd ocaml-extlib && git checkout ${BRANCH} && git pull && cd -;

git clone ${MINA}/ppx_optcomp.git && cd ppx_optcomp && git checkout ${BRANCH} && git pull && cd ..;

git clone ${MINA}/rpc_parallel.git && cd rpc_parallel && git checkout ${BRANCH} && git pull && cd -;

## not yet migrated to o1labs/mina

git clone ${OBAZL}/ocaml-jemalloc.git && cd ocaml-jemalloc && git checkout ${BRANCH} && git pull && cd -;

git clone ${OBAZL}/orocksdb.git && cd orocksdb && git checkout ${ROCKS_BRANCH} && git pull && cd -;

git clone ${OBAZL}/ocaml-sodium.git && cd ocaml-sodium && git checkout ${BRANCH} && git pull && cd -;
