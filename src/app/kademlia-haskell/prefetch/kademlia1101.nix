{ mkDerivation, base, binary, bytestring, containers, contravariant
, cryptonite, data-default, errors, extra, fetchgit, HUnit, memory
, MonadRandom, mtl, network, QuickCheck, quickcheck-instances
, random, random-shuffle, stdenv, stm, tasty, tasty-hunit
, tasty-quickcheck, time, transformers, transformers-compat
}:
mkDerivation {
  pname = "kademlia";
  version = "1.1.0.1";
  src = fetchgit {
    url = "https://github.com/bkase/kademlia.git";
    sha256 = "11jkwwissfkqnnsibgb17a25hzjijh0ybnss4msw9i7slhnq8d6m";
    rev = "e6fd924c36701fb338702a929f70f06c24f2e7e2";
  };
  isLibrary = true;
  isExecutable = true;
  libraryHaskellDepends = [
    base bytestring containers contravariant cryptonite extra memory
    MonadRandom mtl network random random-shuffle stm time transformers
  ];
  executableHaskellDepends = [
    base binary bytestring containers data-default extra MonadRandom
    mtl network random random-shuffle transformers transformers-compat
  ];
  testHaskellDepends = [
    base binary bytestring containers data-default errors extra HUnit
    MonadRandom mtl network QuickCheck quickcheck-instances random
    random-shuffle stm tasty tasty-hunit tasty-quickcheck time
    transformers transformers-compat
  ];
  doCheck = false;
  homepage = "https://github.com/serokell/kademlia";
  description = "An implementation of the Kademlia DHT Protocol";
  license = stdenv.lib.licenses.bsd3;
}
