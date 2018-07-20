FROM gcr.io/o1labs-192920/ocaml-base:cb142209e77e4e3f4fe05d192bdb1e85cc879d6d

ENV PATH "/home/opam/.opam/4.06.1/bin:$PATH"
ENV CAML_LD_LIBRARY_PATH "/home/opam/.opam/4.06.1/lib/stublibs"
ENV MANPATH "/home/opam/.opam/4.06.1/man:"
ENV PERL5LIB "/home/opam/.opam/4.06.1/lib/perl5"
ENV OCAML_TOPLEVEL_PATH "/home/opam/.opam/4.06.1/lib/toplevel"
ENV FORCE_BUILD 1

RUN sudo apt-get install --yes python
RUN CLOUDSDK_CORE_DISABLE_PROMPTS=1 curl https://sdk.cloud.google.com | bash
RUN ~/google-cloud-sdk/bin/gcloud --quiet components update
RUN ~/google-cloud-sdk/bin/gcloud components install kubectl

WORKDIR /home/opam/app

ENV TERM=xterm-256color
ENV PATH "~/google-cloud-sdk/bin:$PATH"

ENTRYPOINT bash

