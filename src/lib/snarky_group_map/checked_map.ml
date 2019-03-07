open Snarky
open Snark

module Params = struct
  type 'f t = {a: 'f; b: 'f}
end

module type S = sig
  val to_group :
    params:'f Params.t -> m:'f m -> 'f Cvar.t -> 'f Cvar.t * 'f Cvar.t
end

module Make
    (M : Snarky.Snark_intf.Run) (Params : sig
        val a : M.field

        val b : M.field
    end) =
    struct 


end
