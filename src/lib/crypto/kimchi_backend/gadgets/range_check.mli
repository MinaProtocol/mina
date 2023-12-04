(** 64-bit range-check gadget - checks value \in [0, 2^64) *)
val bits64 :
     (module Snarky_backendless.Snark_intf.Run with type field = 'f)
  -> 'f Snarky_backendless.Cvar.t (* value *)
  -> unit

(** multi-range-check gadget - checks v0,v1,v2 \in [0, 2^88) *)
val multi :
     (module Snarky_backendless.Snark_intf.Run with type field = 'f)
  -> 'f Snarky_backendless.Cvar.t (* v0 *)
  -> 'f Snarky_backendless.Cvar.t (* v1 *)
  -> 'f Snarky_backendless.Cvar.t (* v2 *)
  -> unit

(** compact multi-range-check gadget - checks
 *     - v0,v1,v2 \in [0, 2^88)
 *     - v01 = v0 + 2^88 * v1 
 *)
val compact_multi :
     (module Snarky_backendless.Snark_intf.Run with type field = 'f)
  -> 'f Snarky_backendless.Cvar.t (* v01 *)
  -> 'f Snarky_backendless.Cvar.t (* v2 *)
  -> 'f Snarky_backendless.Cvar.t * 'f Snarky_backendless.Cvar.t
(* v0, v1 *)
