open Core_kernel

module Rounds = struct
  let rounds_full = 8

  let rounds_partial = 30
end

let high_entropy_bits = 256

module Make (Field : Zexe_backend.Field.S) = struct
  module Inputs = struct
    include Rounds
    module Field = Field

    let to_the_alpha x =
      let open Field in
      let res = square x in
      Mutable.square res ;
      (* x^4 *)
      Mutable.square res ;
      (* x^8 *)
      Mutable.square res ;
      (* x^16 *)
      res *= x ;
      res

    module Operations = struct
      let add_assign ~state i x = Field.(state.(i) += x)

      let apply_affine_map (_rows, c) v =
        let open Field in
        let res = [|v.(0) + v.(2); v.(0) + v.(1); v.(1) + v.(2)|] in
        Array.iteri res ~f:(fun i ri -> ri += c.(i)) ;
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
      end)
      (Inputs.Field)
      (Field)

  let digest params elts =
    let sponge = Bits.create params in
    Array.iter elts ~f:(Bits.absorb sponge) ;
    Bits.squeeze sponge ~length:256
end
