val domains :
     ?min_log2:int
       (** The minimum domain size to calculate. This can be overridden if
           there are e.g. fixed-size lookup tables that will affect the domain
           size of the circuit.
        *)
  -> (module Snarky_backendless.Snark_intf.Run with type field = 'field)
  -> ('a, 'b, 'field) Import.Spec.ETyp.t
  -> ('c, 'd, 'field) Import.Spec.ETyp.t
  -> ('a -> 'c)
  -> Import.Domains.t

val rough_domains : Import.Domains.t
