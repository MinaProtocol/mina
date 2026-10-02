(* The queries behind the hard fork checks and the canonical-chain repair now
   live in the archive library, so that the archive itself can run the repair
   without depending on this toolbox -- the dependency only goes the other way.

   Kept as a shim so that callers here continue to say [Sql.foo]. *)

include Archive_lib.Hardfork_sql
