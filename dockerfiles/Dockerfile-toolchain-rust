FROM rust:latest

ADD /src/app/trace-tool /src

# Fetches + caches the cargo registry and our dependencies, as well as building
# them so later builds are substantially faster.

RUN cd /src ; cargo build
