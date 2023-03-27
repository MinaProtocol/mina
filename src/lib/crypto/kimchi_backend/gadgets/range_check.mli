(* 64-bit range-check gadget - checks v0 \in [0, 2^64) *)
val range_check64 :
     (module Snarky_backendless.Snark_intf.Run with type field = 'f)
  -> 'f Snarky_backendless.Cvar.t
  -> unit

(* multi-range-check gadget - checks v0,v1,v2 \in [0, 2^88) *)
val multi_range_check :
     (module Snarky_backendless.Snark_intf.Run with type field = 'f)
  -> 'f Snarky_backendless.Cvar.t
  -> 'f Snarky_backendless.Cvar.t
  -> 'f Snarky_backendless.Cvar.t
  -> unit

(* compact multi-range-check gadget - checks
 *     - v0,v1,v2 \in [0, 2^88)
 *     - v01 = v0 + 2^88 * v1 *)
val compact_multi_range_check :
     (module Snarky_backendless.Snark_intf.Run with type field = 'f)
  -> 'f Snarky_backendless.Cvar.t
  -> 'f Snarky_backendless.Cvar.t
  -> unit
