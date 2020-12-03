open Core_kernel
open Snarky_backendless

val wrap :
     'f Snark.m
  -> potential_xs:('input -> 'f Cvar.t * 'f Cvar.t * 'f Cvar.t)
  -> y_squared:(x:'f Cvar.t -> 'f Cvar.t)
  -> ('input -> 'f Cvar.t * 'f Cvar.t) Staged.t

module Make
    (M : Snarky_backendless.Snark_intf.Run) (Params : sig
        val params : M.field Group_map.Params.t
    end) : sig
  val to_group : M.Field.t -> M.Field.t * M.Field.t
end
