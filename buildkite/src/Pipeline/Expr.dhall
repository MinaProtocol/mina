let MainlineBranch = ./MainlineBranch.dhall

let Expr =
    -- Conditions under which a job is included or excluded:
    -- - DescendantOf: the commit's closest mainline branch is the ancestor;
    -- - CodebaseTargetsUnreleasedNetwork: MINA_CODEBASE_NETWORK differs from
    --   MINA_MAINNET_NETWORK exactly when codebaseTargetsUnreleasedNetwork is
    --   True, i.e. the codebase is developing a network not yet on mainnet.
    --
    -- dhall-to-yaml drops the constructor, so each alternative's record must be
    -- told apart by its fields: monorepo_lib.sh does so to evaluate them.
      < DescendantOf : { ancestor : MainlineBranch.Type, reason : Text }
      | CodebaseTargetsUnreleasedNetwork :
          { codebaseTargetsUnreleasedNetwork : Bool, reason : Text }
      >

in  { Type = Expr }
