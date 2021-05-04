open Core_kernel

module type S = Intf.S

module type Config = Intf.Config

(* The functor to create the hash function based on Inputs *)
module Make (Config : Intf.Config) :
  Intf.S with type boolean := Config.boolean = struct
  (* the state is simply an array *)
  module State = struct
    include Array

    let map2 = map2_exn
  end

  module Field = Config.Field (* unecessary *)

  type field = Field.t

  type field_constant = Field.t

  (* type boolean = Config.boolean *)

  (* make the digest (based on Field) *)
  module Digest = struct
    type t = field

    let to_bits ?length x =
      match length with
      | None ->
          Field.unpack x
      | Some length ->
          List.take (Field.unpack x) length
  end

  (* make the hash (based on Inputs) *)
  module Hash = Sponge.Make_hash (Sponge.Poseidon (Config))

  (* hash stuff *)
  let initial_state = Hash.initial_state

  let digest = Hash.digest

  let params : Field.t Sponge.Params.t =
    Sponge.Params.(map pasta_p ~f:Field.of_string)

  let update ~state = Hash.update ~state params

  let hash ?init = Hash.hash ?init params

  (* bit stuff *)
  let pack_input =
    let module Input = Random_oracle_input in
    Input.pack_to_fields ~size_in_bits:Field.size_in_bits ~pack:Field.project

  let prefix_to_field (s : string) =
    let bits_per_character = 8 in
    assert (bits_per_character * String.length s < Field.size_in_bits) ;
    Field.project Fold_lib.Fold.(to_list (string_bits (s :> string)))

  let salt (s : string) = update ~state:Hash.initial_state [|prefix_to_field s|]
end

(* tests *)

let%test_module _ =
  ( module struct
    module MiniField = struct
      type t = int

      let zero = 0

      let ( * ) a b = a * b mod 5

      let ( + ) a b = (a + b) mod 5

      let unpack (field : t) =
        match field with
        | 0 ->
            [false; false; false]
        | 1 ->
            [false; false; true]
        | 2 ->
            [false; true; false]
        | 3 ->
            [false; true; true]
        | 4 ->
            [true; false; false]
        | _ ->
            failwith "not supposed to happen"

      let size = Bigint.of_int 5

      let size_in_bits = 3

      let project bits =
        match bits with
        | [false; false; false] ->
            0
        | [false; false; true] ->
            1
        | [false; true; false] ->
            2
        | [false; true; true] ->
            3
        | [true; false; false] ->
            4
        | _ ->
            failwith "not supposed to happen"

      let of_string str = Int.of_string str
    end

    module Config : Config with type boolean = bool = struct
      type boolean = bool

      module Field = MiniField

      let rounds_full = 1

      let rounds_partial = 0

      (* Computes x^5 *)
      let to_the_alpha x =
        let open Field in
        let res = x in
        let res = res * res in
        (* x^2 *)
        let res = res * res in
        (* x^4 *)
        res * x

      module Operations = struct
        let add_assign ~state i x = Field.(state.(i) <- state.(i) + x)

        let apply_affine_map (matrix, constants) v =
          let dotv row =
            Array.reduce_exn
              (Array.map2_exn row v ~f:Field.( * ))
              ~f:Field.( + )
          in
          let res = Array.map matrix ~f:dotv in
          Array.map2_exn res constants ~f:Field.( + )

        let copy a = Array.map a ~f:Fn.id
      end
    end

    let%test_unit "some test" =
      let module Hash = Make (Config) in
      let init = Hash.initial_state in
      let digest = Hash.digest init in
      let bits = Hash.Digest.to_bits digest in
      List.iter bits ~f:(fun x -> printf "%B" x)
  end )
