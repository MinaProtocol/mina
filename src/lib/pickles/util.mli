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
  'f 'field_var 'n.
     first_zero:'field_var
  -> (module Snarky_backendless.Snark_intf.Run
        with type field = 'f
         and type field_var = 'field_var )
  -> 'n Pickles_types.Nat.t
  -> ('field_var Snarky_backendless.Boolean.t, 'n) Pickles_types.Vector.t

val lowest_128_bits :
     constrain_low_bits:bool
  -> assert_128_bits:('field_var -> unit)
  -> (module Snarky_backendless.Snark_intf.Run
        with type field = 'f
         and type field_var = 'field_var )
  -> 'field_var
  -> 'field_var
