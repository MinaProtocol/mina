(*TODO: perhaps move this to an internal file, as the dummy gate could be misleading for users *)
module Circuit := Kimchi_pasta_snarky_backend.Step_impl

(** Looks up three values (at most 12 bits each) 
 * BEWARE: it needs in the circuit at least one gate (even if dummy) that uses the 12-bit lookup table for it to work 
 *)
val three_12bit :
     Circuit.Field.t (* v0 *)
  -> Circuit.Field.t (* v1 *)
  -> Circuit.Field.t (* v2 *)
  -> unit

(** Check that one value is at most X bits (at most 12). Default is 12.
 * BEWARE: it needs in the circuit at least one gate (even if dummy) that uses the 12-bit lookup table for it to work
 *)
val less_than_bits : ?bits:int (* bits *) -> Circuit.Field.t (* value *) -> unit
