FROM codaprotocol/coda:toolchain-e11592718bee89d2a4facfa7ca209844fa7b140c

ENV OPAM_DIR             "/home/opam/.opam/4.07"
ENV PATH                 "${OPAM_DIR}/bin:$PATH"
ENV CAML_LD_LIBRARY_PATH "${OPAM_DIR}/lib/stublibs"
ENV MANPATH              "${OPAM_DIR}/man:"
ENV PERL5LIB             "${OPAM_DIR}/lib/perl5"
ENV OCAML_TOPLEVEL_PATH  "${OPAM_DIR}/lib/toplevel"

WORKDIR /home/opam/app

ENV TERM=xterm-256color
ENV PATH "~/google-cloud-sdk/bin:$PATH"

# Utility to adjust uid to match host OS
# https://github.com/boxboat/fixuid

ENV FIXUID_SHA256 d4555f5ba21298819af24ed351851a173fff02b9c0bd5dfcef32f7e22ef06401
RUN USER=opam && \
    GROUP=opam && \
    sudo curl -SsL https://github.com/boxboat/fixuid/releases/download/v0.4/fixuid-0.4-linux-amd64.tar.gz > /tmp/fixuid-0.4-linux-amd64.tar.gz && \
    sudo echo "$FIXUID_SHA256 /tmp/fixuid-0.4-linux-amd64.tar.gz" | sha256sum -c && \
    sudo tar -C /usr/local/bin -xzf /tmp/fixuid-0.4-linux-amd64.tar.gz && \
    sudo rm /tmp/fixuid-0.4-linux-amd64.tar.gz && \
    sudo chown root:root /usr/local/bin/fixuid && \
    sudo chmod 4755 /usr/local/bin/fixuid && \
    sudo mkdir -p /etc/fixuid && \
    sudo printf "user: $USER\ngroup: $GROUP\npaths: ['/home/opam','/nix']\n" | sudo tee /etc/fixuid/config.yml > /dev/null

USER opam:opam
ENTRYPOINT ["fixuid"]


