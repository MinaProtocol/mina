FROM gcr.io/o1labs-192920/ocaml-base:f1db9a46932c092deee291da8f91dbd4430398f7

ENV PATH "/home/opam/.opam/4.05.0/bin:$PATH"
ENV CAML_LD_LIBRARY_PATH "/home/opam/.opam/4.05.0/lib/stublibs"
ENV MANPATH "/home/opam/.opam/4.05.0/man:"
ENV PERL5LIB "/home/opam/.opam/4.05.0/lib/perl5"
ENV OCAML_TOPLEVEL_PATH "/home/opam/.opam/4.05.0/lib/toplevel"
ENV FORCE_BUILD 1

RUN sudo apt-get install --yes python
RUN CLOUDSDK_CORE_DISABLE_PROMPTS=1 curl https://sdk.cloud.google.com | bash
RUN ~/google-cloud-sdk/bin/gcloud --quiet components update
RUN ~/google-cloud-sdk/bin/gcloud components install kubectl

WORKDIR /home/opam/app

ENV TERM=xterm-256color
ENV PATH "~/google-cloud-sdk/bin:$PATH"

ENTRYPOINT bash

