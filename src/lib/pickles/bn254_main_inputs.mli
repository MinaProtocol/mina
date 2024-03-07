module Impl = Impls.Bn254

module Sponge : sig
  module Permutation :
      module type of
        Sponge_inputs.Make
          (Impl)
          (struct
            include Bn254_field_sponge.Inputs

            let params = Bn254_field_sponge.params
          end)

  module S : module type of Sponge.Make_sponge (Permutation)

  include module type of S

  (** Alias for [S.squeeze] *)
  val squeeze_field : t -> Permutation.Field.t

  (** Extension of [S.absorb]*)
  val absorb :
       t
    -> [< `Bits of Impls.Bn254.Boolean.var list | `Field of Permutation.Field.t ]
    -> unit
end
