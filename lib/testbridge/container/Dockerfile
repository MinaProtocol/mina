FROM ocaml/opam

RUN opam depext -i jbuilder
RUN opam install core
RUN opam install async

EXPOSE 2115:2115/udp

WORKDIR /testbridge

ADD . /testbridge

RUN sudo mkdir /app

run sudo chown -R opam /testbridge
run sudo chown -R opam /app

RUN eval `opam config env` && jbuilder build

CMD bash -c "while true; do ./_build/install/default/bin/main; sleep 1; done"
