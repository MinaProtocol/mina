Aliases without a (env) dependency are not rebuilt when the environment
changes:

  $ dune build @without_dep
             a alias without_dep
  X is not set
  Y is not set
  $ X=x dune build @without_dep

But if there is a dependency, the alias gets rebuilt:

  $ dune build @with_dep
             a alias with_dep
  X is not set
  Y is not set
  $ X=x dune build @with_dep
             a alias with_dep
  X = "x"
  Y is not set

This only happens for tracked variables:

  $ dune build @with_dep
             a alias with_dep
  X is not set
  Y is not set
  $ Y=y dune build @with_dep
