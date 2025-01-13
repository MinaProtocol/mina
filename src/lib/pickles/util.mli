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

module Make (Impl : Kimchi_pasta_snarky_backend.Snark_intf) : sig
  open Impl

  val ones_vector :
       first_zero:Field.t
    -> 'n Pickles_types.Nat.t
    -> (Boolean.var, 'n) Pickles_types.Vector.t

  val seal : Field.t -> Field.t

  val lowest_128_bits :
       constrain_low_bits:bool
    -> assert_128_bits:(Field.t -> unit)
    -> Field.t
    -> Field.t
end

module Step : module type of Make (Kimchi_pasta_snarky_backend.Step_impl)

module Wrap : module type of Make (Kimchi_pasta_snarky_backend.Wrap_impl)
