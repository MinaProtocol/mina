(** Determines the domain size used for 'wrap proofs'. This can be determined by
    the fixpoint function provided by {!val:Wrap_domains.f_debug}, but for
    efficiently this is disabled in production and uses the hard-coded results.
*)

val domains :
     ?feature_flags:bool Vinegar_types.Plonk_types.Features.t
  -> ('a, 'b) Import.Spec.Step_etyp.t
  -> ('c, 'd) Import.Spec.Step_etyp.t
  -> ('a -> 'c Promise.t)
  -> Import.Domains.t Promise.t

val wrap_domains :
     ?feature_flags:bool Vinegar_types.Plonk_types.Features.t
  -> ('a, 'b) Import.Spec.Wrap_etyp.t
  -> ('c, 'd) Import.Spec.Wrap_etyp.t
  -> ('a -> 'c Promise.t)
  -> Import.Domains.t Promise.t

val rough_domains : Import.Domains.t
