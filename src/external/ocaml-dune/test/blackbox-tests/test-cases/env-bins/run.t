Basic test that we can use private binaries as public ones
  $ dune build --root private-bin-import
  Entering directory 'private-bin-import'
          priv alias using-priv/runtest
  Executing priv as priv
  PATH:
  	_build/default/test/blackbox-tests/test-cases/env-bins/private-bin-import/_build/default/using-priv/.bin
  	_build/default/test/blackbox-tests/test-cases/env-bins/private-bin-import/_build/install/default/bin
  	_build/install/default/bin
  priv-renamed alias using-priv/runtest
  Executing priv as priv-renamed
  PATH:
  	_build/default/test/blackbox-tests/test-cases/env-bins/private-bin-import/_build/default/using-priv/.bin
  	_build/default/test/blackbox-tests/test-cases/env-bins/private-bin-import/_build/install/default/bin
  	_build/install/default/bin

Override public binary in env
  $ dune build --root override-bins
  Entering directory 'override-bins'
           foo alias test/runtest
  private binary
           foo alias default
  public binary
