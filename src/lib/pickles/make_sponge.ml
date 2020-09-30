module D = Composition_types.Digest
open Core_kernel

module Rounds = struct
  let rounds_full = 63

  let rounds_partial = 0
end

let high_entropy_bits = 128

module Make (Field : Zexe_backend.Field.S) = struct
  module Inputs = struct
    include Rounds
    module Field = Field

    let to_the_alpha x =
      let open Field in
      let res = square x in
      Mutable.square res ; (* x^4 *)
                           res *= x ; (* x^5 *)
                                      res

    module Operations = struct
      let add_assign ~state i x = Field.(state.(i) += x)

      let apply_affine_map (matrix, constants) v =
        let dotv row =
          Array.reduce_exn (Array.map2_exn row v ~f:Field.( * )) ~f:Field.( + )
        in
        let res = Array.map matrix ~f:dotv in
        for i = 0 to Array.length res - 1 do
          Field.(res.(i) += constants.(i))
        done ;
        res

      let copy a = Array.map a ~f:(fun x -> Field.(x + zero))
    end
  end

  module Field = Sponge.Make_sponge (Sponge.Poseidon (Inputs))

  module Bits =
    Sponge.Bit_sponge.Make
      (Bool)
      (struct
        include Inputs.Field

        let high_entropy_bits = high_entropy_bits

        let finalize_discarded = ignore
      end)
      (Inputs.Field)
      (Field)

  let digest params elts =
    let sponge = Bits.create params in
    Array.iter elts ~f:(Bits.absorb sponge) ;
    Bits.squeeze_field sponge |> Inputs.Field.to_bits |> D.Constant.of_bits
end
