val absorb :
  'a 'g1 'g1_opt 'f 'scalar.
     absorb_field:('f -> unit)
  -> absorb_scalar:('scalar -> unit)
  -> g1_to_field_elements:('g1 -> 'f list)
  -> mask_g1_opt:('g1_opt -> 'g1)
  -> ( 'a
     , < base_field : 'f ; g1 : 'g1 ; g1_opt : 'g1_opt ; scalar : 'scalar > )
     Type.t
  -> 'a
  -> unit

val ones_vector :
  'f 'n.
     first_zero:'f Snarky_backendless.Cvar.t
  -> (module Snarky_backendless.Snark_intf.Run with type field = 'f)
  -> 'n Pickles_types.Nat.t
  -> ( 'f Snarky_backendless.Cvar.t Snarky_backendless.Boolean.t
     , 'n )
     Pickles_types.Vector.t

(** *)
val seal :
     (module Snarky_backendless.Snark_intf.Run with type field = 'f)
  -> 'f Snarky_backendless__.Cvar.t
  -> 'f Snarky_backendless__.Cvar.t

(** *)
val lowest_128_bits :
     constrain_low_bits:bool
  -> assert_128_bits:('f Snarky_backendless__.Cvar.t -> unit)
  -> (module Snarky_backendless.Snark_intf.Run with type field = 'f)
  -> 'f Snarky_backendless__.Cvar.t
  -> 'f Snarky_backendless__.Cvar.t
