val domains :
     'field Snarky_backendless.Snark.m
  -> ('a, 'b, 'field) Import.Spec.ETyp.t
  -> ('c, 'd, 'field) Import.Spec.ETyp.t
  -> ('a -> 'c)
  -> Import.Domains.t

val rough_domains : Import.Domains.t
