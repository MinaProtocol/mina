FROM gcr.io/o1labs-192920/ocaml-base:d6eecbf879e7badc4faa83f1b3c8421abd146621

ENV PATH "/home/opam/.opam/4.05.0/bin:$PATH"
ENV CAML_LD_LIBRARY_PATH "/home/opam/.opam/4.05.0/lib/stublibs"
ENV MANPATH "/home/opam/.opam/4.05.0/man:"
ENV PERL5LIB "/home/opam/.opam/4.05.0/lib/perl5"
ENV OCAML_TOPLEVEL_PATH "/home/opam/.opam/4.05.0/lib/toplevel"
ENV FORCE_BUILD 1

WORKDIR /home/opam/app

ENV TERM=xterm-256color

ENTRYPOINT bash

