FROM gcr.io/o1labs-192920/ocaml-base:20472b5c2589370954463f27a7f84501a17206f0

ENV PATH "/home/opam/.opam/4.07.0/bin:$PATH"
ENV CAML_LD_LIBRARY_PATH "/home/opam/.opam/4.07.0/lib/stublibs"
ENV MANPATH "/home/opam/.opam/4.07.0/man:"
ENV PERL5LIB "/home/opam/.opam/4.07.0/lib/perl5"
ENV OCAML_TOPLEVEL_PATH "/home/opam/.opam/4.07.0/lib/toplevel"

RUN sudo apt-get install --yes python
RUN CLOUDSDK_CORE_DISABLE_PROMPTS=1 curl https://sdk.cloud.google.com | bash
RUN ~/google-cloud-sdk/bin/gcloud --quiet components update
RUN ~/google-cloud-sdk/bin/gcloud components install kubectl

WORKDIR /home/opam/app

ENV TERM=xterm-256color
ENV PATH "~/google-cloud-sdk/bin:$PATH"

# Utility to adjust uid to match host OS
# https://github.com/boxboat/fixuid
RUN USER=opam && \
    GROUP=opam && \
    sudo curl -SsL https://github.com/boxboat/fixuid/releases/download/v0.4/fixuid-0.4-linux-amd64.tar.gz | sudo tar -C /usr/local/bin -xzf - && \
    sudo chown root:root /usr/local/bin/fixuid && \
    sudo chmod 4755 /usr/local/bin/fixuid && \
    sudo mkdir -p /etc/fixuid && \
    sudo printf "user: $USER\ngroup: $GROUP\n" | sudo tee /etc/fixuid/config.yml > /dev/null

USER opam:opam
ENTRYPOINT ["fixuid"]


