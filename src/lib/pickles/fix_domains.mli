val domains :
     (module Snarky_backendless.Snark_intf.Run
        with type field = 'field
         and type field_var = 'field_var
         and type run_state = 'state )
  -> ('a, 'b, 'field, 'field_var, 'state) Import.Spec.ETyp.t
  -> ('c, 'd, 'field, 'field_var, 'state) Import.Spec.ETyp.t
  -> ('a -> 'c)
  -> Import.Domains.t

val rough_domains : Import.Domains.t
