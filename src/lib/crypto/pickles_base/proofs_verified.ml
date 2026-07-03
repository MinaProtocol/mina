open Core_kernel
open Pickles_types

[@@@warning "-4"] (* sexp-related fragile pattern-matching warning *)

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V2 = struct
    type t = Mina_wire_types.Pickles_base.Proofs_verified.V2.t =
      | N0
      | N1
      | N2
      | N_other of int
    [@@deriving sexp, compare, yojson, hash, equal]

    let to_latest = Fn.id
  end

  module V1 = struct
    type t = Mina_wire_types.Pickles_base.Proofs_verified.V1.t = N0 | N1 | N2
    [@@deriving sexp, compare, yojson, hash, equal]

    let to_latest = function
      | N0 ->
          Latest.N0
      | N1 ->
          Latest.N1
      | N2 ->
          Latest.N2
  end
end]

type t = N0 | N1 | N2 | N_other of int
[@@deriving sexp, compare, yojson, hash, equal]

[@@@warning "+4"]

let to_int : t -> int = function N0 -> 0 | N1 -> 1 | N2 -> 2 | N_other i -> i

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
  | S (S n) ->
      N_other (2 + Nat.to_int n)

let of_int_exn (n : int) : t =
  match n with 0 -> N0 | 1 -> N1 | 2 -> N2 | _ -> N_other n

(* Conversions between the in-memory [t] and the serialised [Stable] encodings.
   The encodings are currently structurally identical to [t]. *)
let to_stable_v2 (x : t) : Stable.V2.t =
  match x with
  | N0 ->
      Stable.V2.N0
  | N1 ->
      Stable.V2.N1
  | N2 ->
      Stable.V2.N2
  | N_other n ->
      Stable.V2.N_other n

let of_stable_v2 (x : Stable.V2.t) : t =
  match x with
  | Stable.V2.N0 ->
      N0
  | Stable.V2.N1 ->
      N1
  | Stable.V2.N2 ->
      N2
  | Stable.V2.N_other n ->
      (* TODO: This should really have an upper bound as well. *)
      if n > 2 then N_other n
      else failwithf "Invalid choice for Proofs_verified.N_other: %i" n ()

let to_stable_v1 (x : t) : Stable.V1.t =
  match x with
  | N0 ->
      Stable.V1.N0
  | N1 ->
      Stable.V1.N1
  | N2 ->
      Stable.V1.N2
  | N_other _ ->
      failwith "Unsupported Proofs_verified.N_other in Stable.V1.t"

let of_stable_v1 (x : Stable.V1.t) : t =
  match x with Stable.V1.N0 -> N0 | Stable.V1.N1 -> N1 | Stable.V1.N2 -> N2

(* The prefix mask is right-aligned: the [to_int t] set bits sit at the end of
   the vector, e.g. [N1] over width 2 is [false; true]. This matches the
   convention used by the consumers (see [wrap_main.ml], which builds the mask
   with [ones_vector |> Vector.rev] and pads with [extend_front_exn]). *)
let to_bool_vec : 'n Nat.t -> proofs_verified -> (bool, 'n) Vector.t =
 fun n t ->
  let stop_idx = to_int t in
  let len = Nat.to_int n in
  Vector.init n ~f:(fun idx -> idx >= len - stop_idx)

let of_bool_vec (v : (bool, 'n) Vector.t) : proofs_verified =
  Vector.foldi (Vector.rev v) ~init:0 ~f:(fun idx count value ->
      if value then
        if idx = count then count + 1
        else
          invalid_arg
            "Prefix_mask.of_bool_vec: expected [false; false; ...; false; \
             true; ...; true; true]"
      else count )
  |> of_int_exn

module Prefix_mask = struct
  open Kimchi_pasta_snarky_backend

  module Step = struct
    open Step_impl

    module Checked = struct
      type 'n t = (Boolean.var, 'n Nat.N2.plus_n) Vector.t
    end

    let typ n : ('n Checked.t, proofs_verified) Typ.t =
      Typ.transport
        (Pickles_types.Vector.typ Boolean.typ n)
        ~there:(to_bool_vec n) ~back:of_bool_vec
  end

  module Wrap = struct
    open Wrap_impl

    module Checked = struct
      type 'n t = (Boolean.var, 'n Nat.N2.plus_n) Vector.t
    end

    let typ n : ('n Checked.t, proofs_verified) Typ.t =
      Typ.transport
        (Pickles_types.Vector.wrap_typ Boolean.typ n)
        ~there:(to_bool_vec n) ~back:of_bool_vec
  end
end

module One_hot = struct
  open Kimchi_pasta_snarky_backend

  module Checked = struct
    type 'n t = 'n Nat.N3.plus_n One_hot_vector.Step.t

    let to_input (type n) (t : n t) =
      Random_oracle_input.Chunked.packeds
        (Array.map
           Pickles_types.(
             Vector.to_array
               (t :> (Step_impl.Boolean.var, n Nat.N3.plus_n) Vector.t))
           ~f:(fun b -> ((b :> Step_impl.Field.t), 1)) )
  end

  let there : proofs_verified -> int = function
    | N0 ->
        0
    | N1 ->
        1
    | N2 ->
        2
    | N_other i ->
        i

  let back : int -> proofs_verified = function
    | 0 ->
        N0
    | 1 ->
        N1
    | 2 ->
        N2
    | n when n < 0 ->
        failwith "Invalid mask"
    | n ->
        N_other n

  let to_input (n : 'n Nat.N3.plus_n Nat.t) ~zero ~one (t : t) =
    let target_idx = to_int t in
    let length = Nat.to_int n in
    if target_idx >= length then
      failwithf
        "Proofs_verified.One_hot.to_input: Attempted to encode %i into an \
         undersized vector (%i)"
        target_idx length () ;
    let one_hot =
      Array.init (Nat.to_int n) ~f:(fun idx ->
          if idx = target_idx then one else zero )
    in
    Random_oracle_input.Chunked.packeds (Array.map one_hot ~f:(fun b -> (b, 1)))

  let typ n : ('n Checked.t, proofs_verified) Step_impl.Typ.t =
    let module M = One_hot_vector.Make (Step_impl) in
    Step_impl.Typ.transport (M.typ n) ~there ~back
end
