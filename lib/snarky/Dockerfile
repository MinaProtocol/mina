FROM ocaml-base:latest


RUN sudo apt-get install libffi-dev
RUN opam install ctypes-foreign
RUN opam install ctypes
RUN opam install jbuilder
RUN opam install merlin
RUN opam install ocp-indent
RUN sudo apt-get install --yes cmake
RUN sudo apt-get install --yes libssl-dev
RUN sudo apt-get install --yes libprocps-dev
RUN sudo apt-get install --yes libgmp-dev
RUN sudo apt-get install --yes libboost-dev
RUN sudo apt-get install --yes libboost-program-options-dev

WORKDIR /camlsnark

RUN sudo chown -R opam /camlsnark
