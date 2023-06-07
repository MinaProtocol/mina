(*TODO: perhaps move this to an internal file, as the dummy gate could be misleading for users *)

(** Looks up three values (at most 12 bits) 
 * BEWARE: it needs in the circuit at least one gate (even if dummy) that uses the table for it to work 
 *)
val three_values :
     (module Snarky_backendless.Snark_intf.Run with type field = 'f)
  -> 'f Snarky_backendless.Cvar.t (* v0 *)
  -> 'f Snarky_backendless.Cvar.t (* v1 *)
  -> 'f Snarky_backendless.Cvar.t (* v2 *)
  -> unit

(** Check that one value is at most X bits (at most 12) 
 * BEWARE: it needs in the circuit at least one gate (even if dummy) that uses the table for it to work
 *)
val less_than_bits :
     (module Snarky_backendless.Snark_intf.Run with type field = 'f)
  -> int
  -> 'f Snarky_backendless.Cvar.t (* value *)
  -> unit
