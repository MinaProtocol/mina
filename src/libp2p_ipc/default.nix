with import <nixpkgs> {};
mkShell {
  buildInputs =
    [ capnproto go_1_16
    ];
}
