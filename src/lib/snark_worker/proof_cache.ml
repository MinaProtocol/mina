(* We are using identity cache. If we want to use an LMDB cache, we need to
   figure out how to pass in path, which likely to make this an reference,
   which is non-ideal *)
let cache_db = Proof_cache_tag.create_identity_db ()
