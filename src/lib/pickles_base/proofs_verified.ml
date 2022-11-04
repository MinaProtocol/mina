open Core_kernel

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

let of_nat (type n) (n : n Pickles_types.Nat.t) : t =
  let open Pickles_types.Nat in
  match n with
  | Z ->
      N0
  | S Z ->
      N1
  | S (S Z) ->
      N2
  | S _ ->
      failwithf "Proofs_verified.of_nat: got %d" (to_int n) ()

type 'f boolean = 'f Snarky_backendless.Cvar.t Snarky_backendless.Boolean.t

type 'a vec2 = ('a, Pickles_types.Nat.N2.n) Pickles_types.Vector.t

module Prefix_mask = struct
  module Checked = struct
    type 'f t = 'f boolean vec2
  end

  let[@warning "-40-42"] there : proofs_verified -> bool vec2 = function
    | N0 ->
        [ false; false ]
    | N1 ->
        [ true; false ]
    | N2 ->
        [ true; true ]

  let[@warning "-40-42"] back : bool vec2 -> proofs_verified = function
    | [ false; false ] ->
        N0
    | [ true; false ] ->
        N1
    | [ true; true ] ->
        N2
    | [ false; true ] ->
        invalid_arg "Prefix_mask.back: invalid mask [false; true]"

  let typ (type f)
      (module Impl : Snarky_backendless.Snark_intf.Run with type field = f) :
      (f Checked.t, proofs_verified) Impl.Typ.t =
    let open Impl in
    Typ.transport
      (Pickles_types.Vector.typ Boolean.typ Pickles_types.Nat.N2.n)
      ~there ~back
end

module One_hot = struct
  module Checked = struct
    type 'f t = ('f, Pickles_types.Nat.N3.n) One_hot_vector.t

    let to_input (type f) (t : f t) =
      Random_oracle_input.Chunked.packeds
        (Array.map
           Pickles_types.(Vector.to_array (t :> (f boolean, Nat.N3.n) Vector.t))
           ~f:(fun b -> ((b :> f Snarky_backendless.Cvar.t), 1)) )
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

  let typ (type f)
      (module Impl : Snarky_backendless.Snark_intf.Run with type field = f) :
      (f Checked.t, proofs_verified) Impl.Typ.t =
    let module M = One_hot_vector.Make (Impl) in
    let open Impl in
    Typ.transport (M.typ Pickles_types.Nat.N3.n) ~there ~back
end
