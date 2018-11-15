  $ jbuilder build foo.cma
  $ cat .merlin
  B _build/default/.foo.objs
  S .
  FLG -open Foo -w -40
  $ rm -f .merlin
  $ jbuilder build foo.cma
  $ cat .merlin
  B _build/default/.foo.objs
  S .
  FLG -open Foo -w -40
  $ echo toto > .merlin
  $ jbuilder build foo.cma
  $ cat .merlin
  B _build/default/.foo.objs
  S .
  FLG -open Foo -w -40
