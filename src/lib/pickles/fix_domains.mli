val domains :
     ?feature_flags:bool Pickles_types.Plonk_types.Features.t
  -> (module Snarky_backendless.Snark_intf.Run with type field = 'field)
  -> ('a, 'b, 'field) Import.Spec.ETyp.t
  -> ('c, 'd, 'field) Import.Spec.ETyp.t
  -> ('a -> 'c)
  -> Import.Domains.t

val rough_domains : Import.Domains.t
