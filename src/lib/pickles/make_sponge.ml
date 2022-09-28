module D = Composition_types.Digest
open Core_kernel

module Rounds = struct
  let rounds_full = 55

  let initial_ark = false

  let rounds_partial = 0
end

let high_entropy_bits = 128

module type S = sig
  module Inputs : sig
    include module type of Rounds

    module Field : Kimchi_backend_common.Field.S

    type field := Field.t

    type fields := field array

    val to_the_alpha : field -> field

    module Operations : Sponge.Intf.Operations with type Field.t = field
  end

  type field := Inputs.Field.t

  (* The name does not really reflect the behavior *and* is somewhat confusing w.r.t
     Inputs.Field. This is almost Sponge.Intf.Sponge *)
  module Field : sig
    type f := Sponge.Poseidon(Inputs).Field.t

    type params := f Sponge.Params.t

    type state := f Sponge.State.t

    type t = f Sponge.t (* TODO: Make this type abstract *)

    val create : ?init:state -> params -> t

    val make :
      state:state -> params:params -> sponge_state:Sponge.sponge_state -> t

    val absorb : t -> f -> unit

    val squeeze : t -> f

    val copy : t -> t

    val state : t -> state
  end

  (* TODO: Resuce module types of Sponge.Intf.Sponge *)
  module Bits : sig
    type t

    val create : ?init:field Sponge.State.t -> field Sponge.Params.t -> t

    val absorb : t -> field -> unit

    val squeeze : t -> length:int -> bool list

    val copy : t -> t

    val state : t -> field Sponge.State.t

    val squeeze_field : t -> field
  end

  val digest :
       field Sponge.Params.t
    -> Inputs.Field.t Core_kernel.Array.t
    -> (int64, Composition_types.Digest.Limbs.n) Pickles_types.Vector.t
end

module Make (Field : Kimchi_backend.Field.S) :
  S with module Inputs.Field = Field = struct
  module Inputs = struct
    include Rounds
    module Field = Field

    (* x^7 *)
    let to_the_alpha x =
      (* square |> mul x |> square |> mul x *)
      (* 7 = 1 + 2 (1 + 2) *)
      let open Field in
      let res = square x in
      res *= x ;
      (* x^3 *)
      Mutable.square res ;
      (* x^6 *)
      res *= x ;
      (* x^7 *)
      res

    module Operations = struct
      module Field = Field

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

module Test
    (Impl : Snarky_backendless.Snark_intf.Run)
    (S_constant : Sponge.Intf.Sponge
                    with module Field := Impl.Field.Constant
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
