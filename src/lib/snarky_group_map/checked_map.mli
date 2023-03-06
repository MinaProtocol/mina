open Core_kernel
open Snarky_backendless

val wrap :
     ('f, 'cvar) Snark.m
  -> potential_xs:('input -> 'cvar * 'cvar * 'cvar)
  -> y_squared:(x:'cvar -> 'cvar)
  -> ('input -> 'cvar * 'cvar) Staged.t

module Make
    (M : Snarky_backendless.Snark_intf.Run) (Params : sig
      val params : M.field Group_map.Params.t
    end) : sig
  val to_group : M.Field.t -> M.Field.t * M.Field.t
end
[@@warning "-67"]
