FROM alpine:3.21
WORKDIR /mina

# Build dependencies
RUN apk add bash build-base git opam

# System dependencies
# postgresql is resolved as postgresql14-dev on Alpine but it's removed, hence using postgresql14-dev instead
RUN apk add gmp-dev libffi-dev libsodium-dev linux-headers lmdb-dev m4 openssl-dev perl pkgconf postgresql15-dev

# OCaml dependencies
COPY opam.export opam.export
RUN opam init --bare -y && \
    opam option --global depext=false && \
    opam repository add -y --all --set-default glyh "https://github.com/glyh/opam-repository.git#corvo/alpine" && \
    opam switch create . 4.14.0 -y && \
    eval $(opam env) && \
    opam switch import ./opam.export -y

COPY . .

CMD ["sh"]
