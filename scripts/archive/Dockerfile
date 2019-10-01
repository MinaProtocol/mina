FROM codaprotocol/coda:toolchain-6b64dedbb6e27f0cc57228f1b44aaa87da489e83

RUN opam init

RUN eval $(opam config env)

COPY ocaml archive-ocaml-script

RUN ls

RUN opam config exec -- dune build archive-ocaml-script/stitch_introspection.exe

RUN chmod 755 _build/default/
