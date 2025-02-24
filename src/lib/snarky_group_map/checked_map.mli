open Core_kernel

val wrap :
     (module Snarky_backendless.Snark_intf.Run
        with type field = 'f
         and type field_var = 'v )
  -> potential_xs:('input -> 'v * 'v * 'v)
  -> y_squared:(x:'v -> 'v)
  -> ('input -> 'v * 'v) Staged.t

module Make
    (M : Snarky_backendless.Snark_intf.Run) (Params : sig
      val params : M.field Group_map.Params.t
    end) : sig
  val to_group : M.Field.t -> M.Field.t * M.Field.t
end
[@@warning "-67"]
