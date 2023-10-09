(** Determines the domain size used for 'wrap proofs'. This can be determined by
    the fixpoint function provided by {!val:Wrap_domains.f_debug}, but for
    efficiently this is disabled in production and uses the hard-coded results.
*)

val domains :
     ?get_feature_flags:
       (   ('field, 'gates) Kimchi_backend_common.Plonk_constraint_system.t
        -> Kimchi_types.feature_flags )
  -> (module Snarky_backendless.Snark_intf.Run
        with type field = 'field
         and type R1CS_constraint_system.t = ( 'field
                                             , 'gates )
                                             Kimchi_backend_common
                                             .Plonk_constraint_system
                                             .t )
  -> ('a, 'b, 'field) Import.Spec.ETyp.t
  -> ('c, 'd, 'field) Import.Spec.ETyp.t
  -> ('a -> 'c)
  -> Import.Domains.t * bool Pickles_types.Plonk_types.Features.t

val rough_domains : Import.Domains.t
