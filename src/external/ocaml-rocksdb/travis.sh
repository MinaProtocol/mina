#!/bin/bash -xue

APT_DEPENDS="g++ build-essential"
APT_OCAML_DEPENDS="ocaml ocaml-native-compilers camlp4-extra opam"
OPAM_DEPENDS="ocamlfind ctypes.0.9.2 ctypes-foreign.0.4.0"

export OPAMYES=1
export OPAMVERBOSE=1
export OPAMCOLOR=never

before_install () {
    echo "Running 'before_install' phase"

    echo "Adding PPA"
    sudo add-apt-repository --yes ppa:avsm/ocaml42+opam12

    echo "Updating Apt cache"
    sudo apt-get update -qq

    echo "Installing general dependencies"
    sudo apt-get install -qq ${APT_DEPENDS}
    echo "Installing dependencies"
    sudo apt-get install -qq ${APT_OCAML_DEPENDS}

    echo "OCaml versions:"
    ocaml -version
    ocamlopt -version

    echo "Opam versions:"
    opam --version
    opam --git-version
}

install () {
    echo "Running 'install' phase"

    opam init
    eval `opam config env`
    opam update

    opam install ${OPAM_DEPENDS}

    CXX=$(./which_g++.sh ) ./install_rocksdb.sh

    make build test
}

script () {
    echo "Running 'script' phase"

    ./rocks_test.native
}

case "$1" in
    before_install)
        before_install
        ;;
    install)
        install
        ;;
    script)
        script
        ;;
    *)
        echo "Usage: $0 {before_install|install|script}"
        exit 1
esac
