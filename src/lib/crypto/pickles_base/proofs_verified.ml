open Core_kernel
open Pickles_types

[@@@warning "-4"] (* sexp-related fragile pattern-matching warning *)

[%%versioned
module Stable = struct
  module V1 = struct
    type t = Mina_wire_types.Pickles_base.Proofs_verified.V1.t = N0 | N1 | N2
    [@@deriving sexp, compare, yojson, hash, equal]

    let to_latest = Fn.id
  end
end]

[@@@warning "+4"]

let to_int : t -> int = function N0 -> 0 | N1 -> 1 | N2 -> 2

(** Inside the circuit, we use two different representations for this type,
    depending on what we need it for.

    Sometimes, we use it for masking out a list of 2 points by taking the
    a prefix of length 0, 1, or 2. In this setting, we we will represent a value
    of this type as a sequence of 2 bits like so:
    00: N0
    10: N1
    11: N2

    We call this a **prefix mask**.

    Sometimes, we use it to select something from a list of 3 values. In this
    case, we will represent a value of this type as a sequence of 3 bits like so:

    100: N0
    010: N1
    001: N2

    We call this a **one-hot vector** as elsewhere.
*)

type proofs_verified = t

let of_nat_exn (type n) (n : n Nat.t) : t =
  let open Nat in
  match n with
  | Z ->
      N0
  | S Z ->
      N1
  | S (S Z) ->
      N2
  | S _ ->
      raise
        (Invalid_argument
           (Printf.sprintf "Proofs_verified.of_nat: got %d" (to_int n)) )

let of_int_exn (n : int) : t =
  match n with
  | 0 ->
      N0
  | 1 ->
      N1
  | 2 ->
      N2
  | _ ->
      raise
        (Invalid_argument (Printf.sprintf "Proofs_verified.of_int: got %d" n))

let to_bool_vec : proofs_verified -> (bool, Nat.N2.n) Vector.t = function
  | N0 ->
      Vector.of_list_and_length_exn [ false; false ] Nat.N2.n
  | N1 ->
      Vector.of_list_and_length_exn [ false; true ] Nat.N2.n
  | N2 ->
      Vector.of_list_and_length_exn [ true; true ] Nat.N2.n

let of_bool_vec (v : (bool, Nat.N2.n) Vector.t) : proofs_verified =
  match Vector.to_list v with
  | [ false; false ] ->
      N0
  | [ false; true ] ->
      N1
  | [ true; true ] ->
      N2
  | [ true; false ] ->
      invalid_arg "Prefix_mask.back: invalid mask [false; true]"
  | _ ->
      invalid_arg "Invalid size"

module Prefix_mask = struct
  open Kimchi_pasta_snarky_backend

  module Step = struct
    open Step_impl

    module Checked = struct
      type t = (Boolean.var, Nat.N2.n) Vector.t
    end

    let typ : (Checked.t, proofs_verified) Typ.t =
      Typ.transport
        (Pickles_types.Vector.typ Boolean.typ Pickles_types.Nat.N2.n)
        ~there:to_bool_vec ~back:of_bool_vec
  end

  module Wrap = struct
    open Wrap_impl

    module Checked = struct
      type t = (Boolean.var, Nat.N2.n) Vector.t
    end

    let typ : (Checked.t, proofs_verified) Typ.t =
      Typ.transport
        (Pickles_types.Vector.wrap_typ Boolean.typ Pickles_types.Nat.N2.n)
        ~there:to_bool_vec ~back:of_bool_vec
  end
end

module One_hot = struct
  open Kimchi_pasta_snarky_backend

  module Checked = struct
    type t = Pickles_types.Nat.N3.n One_hot_vector.Step.t

    let to_input (t : t) =
      Random_oracle_input.Chunked.packeds
        (Array.map
           Pickles_types.(
             Vector.to_array (t :> (Step_impl.Boolean.var, Nat.N3.n) Vector.t))
           ~f:(fun b -> ((b :> Step_impl.Field.t), 1)) )
  end

  let there : proofs_verified -> int = function N0 -> 0 | N1 -> 1 | N2 -> 2

  let back : int -> proofs_verified = function
    | 0 ->
        N0
    | 1 ->
        N1
    | 2 ->
        N2
    | _ ->
        failwith "Invalid mask"

  let to_input ~zero ~one (t : t) =
    let one_hot =
      match t with
      | N0 ->
          [| one; zero; zero |]
      | N1 ->
          [| zero; one; zero |]
      | N2 ->
          [| zero; zero; one |]
    in
    Random_oracle_input.Chunked.packeds (Array.map one_hot ~f:(fun b -> (b, 1)))

  let typ : (Checked.t, proofs_verified) Step_impl.Typ.t =
    let module M = One_hot_vector.Make (Step_impl) in
    Step_impl.Typ.transport (M.typ Pickles_types.Nat.N3.n) ~there ~back
end
