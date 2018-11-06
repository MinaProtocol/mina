{ mkDerivation, base, base64-bytestring, binary, bytestring
, containers, data-default, extra, hashable, kademlia, MonadRandom
, mtl, network, random, random-shuffle, stdenv, transformers
, transformers-compat, unix
}:
mkDerivation {
  pname = "kademlia-haskell";
  version = "0.1.0.0";
  src = ./.;
  isLibrary = false;
  isExecutable = true;
  executableHaskellDepends = [
    base base64-bytestring binary bytestring containers data-default
    extra hashable kademlia MonadRandom mtl network random
    random-shuffle transformers transformers-compat unix
  ];
  license = stdenv.lib.licenses.asl20;
}
