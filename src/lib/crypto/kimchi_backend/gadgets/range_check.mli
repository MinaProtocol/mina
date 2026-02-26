module Circuit := Kimchi_pasta_snarky_backend.Step_impl

(** 64-bit range-check gadget - checks value is in [0, 2^64). *)
val bits64 : Circuit.Field.t (* value *) -> unit

(** Multi-range-check gadget - checks v0, v1, v2 are in [0, 2^88). *)
val multi :
     Circuit.Field.t (* v0 *)
  -> Circuit.Field.t (* v1 *)
  -> Circuit.Field.t (* v2 *)
  -> unit

(** Compact multi-range-check gadget. Checks:
    - v0, v1, v2 are in [0, 2^88)
    - v01 = v0 + 2^88 * v1 *)
val compact_multi :
  Circuit.Field.t (* v01 *) -> Circuit.Field.t (* v2 *) -> unit
