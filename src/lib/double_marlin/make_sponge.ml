open Core_kernel

module Make (Field : Snarky_bn382_backend.Field.S) = struct
  module Rounds = struct
    let rounds_full = 8

    let rounds_partial = 55
  end

  module Inputs = struct
    include Rounds
    module Field = Field

    (* TODO: Square in place *)
    let to_the_alpha x =
      let open Field in
      let x4 = square (square x) in
      x4 *= x ; x4

    module Operations = struct
      let add_assign ~state i x = Field.(state.(i) += x)

      let apply_affine_map (rows, c) v =
        Array.mapi rows ~f:(fun j row ->
            let open Field in
            let res = zero + zero in
            Array.iteri row ~f:(fun i r -> res += (r * v.(i))) ;
            res += c.(j) ;
            res )

      let copy a = Array.map a ~f:(fun x -> Field.(x + zero))
    end
  end

  module Field = Sponge.Make_sponge (Sponge.Poseidon (Inputs))
  module Bits = Sponge.Make_bit_sponge (Bool) (Inputs.Field) (Field)

  (* TODO: Check digest length here *)
  let digest params elts =
    let sponge = Bits.create params in
    Array.iter elts ~f:(Bits.absorb sponge) ;
    Bits.squeeze sponge ~length:256
end
