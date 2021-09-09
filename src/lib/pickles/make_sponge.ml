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

module T (M : Sponge.Intf.T) = M

module Test
    (Impl : Snarky_backendless.Snark_intf.Run with type prover_state = unit)
    (S_constant : Sponge.Intf.Sponge
                  with module Field := T(Impl.Field.Constant)
                   and module State := Sponge.State
                   and type input := Impl.field
                   and type digest := Impl.field)
    (S_checked : Sponge.Intf.Sponge
                 with module Field := Impl.Field
                  and module State := Sponge.State
                  and type input := Impl.Field.t
                  and type digest := Impl.Field.t) =
struct
  open Impl

  let test params : unit =
    let n = 10 in
    let a = Array.init n ~f:(fun _ -> Field.Constant.random ()) in
    Impl.Internal_Basic.Test.test_equal ~sexp_of_t:Field.Constant.sexp_of_t
      ~equal:Field.Constant.equal
      (Typ.array ~length:n Field.typ)
      Field.typ
      (fun a ->
        make_checked (fun () ->
            let s =
              S_checked.create (Sponge.Params.map ~f:Field.constant params)
            in
            Array.iter a ~f:(S_checked.absorb s) ;
            S_checked.squeeze s ) )
      (fun a ->
        let s = S_constant.create params in
        Array.iter a ~f:(S_constant.absorb s) ;
        S_constant.squeeze s )
      a
end
