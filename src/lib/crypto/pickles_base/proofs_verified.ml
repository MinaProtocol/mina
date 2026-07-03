open Core
open Pickles_types

[@@@warning "-4"] (* sexp-related fragile pattern-matching warning *)

[%%versioned
module Stable = struct
  [@@@no_toplevel_latest_type]

  module V2 = struct
    (* Any non-negative count. For [0], [1] and [2] the bin_prot encoding is
       byte-identical to [V1]'s constructor tags. *)
    type t = int [@@deriving sexp, compare, yojson, hash, equal]

    let to_latest = Fn.id
  end

  module V1 = struct
    type t = Mina_wire_types.Pickles_base.Proofs_verified.V1.t = N0 | N1 | N2
    [@@deriving sexp, compare, yojson, hash, equal]

    let to_latest : t -> V2.t = function N0 -> 0 | N1 -> 1 | N2 -> 2
  end
end]

[@@@warning "+4"]

type t = int [@@deriving sexp, compare, yojson, hash, equal]

let to_int : t -> int = Fn.id

(** Inside the circuit, we use two different representations for this type,
    depending on what we need it for.

    Sometimes, we use it for masking out a list of points by taking a prefix of
    length [0 .. n]. In this setting, we we will represent a value of this type
    as a sequence of [n] bits, e.g. for [n = 2]:
    00: 0
    10: 1
    11: 2

    We call this a **prefix mask**.

    Sometimes, we use it to select something from a list of values. In this
    case, we will represent a value of this type as a one-hot sequence of bits,
    e.g. over 3 bits:

    100: 0
    010: 1
    001: 2

    We call this a **one-hot vector** as elsewhere.
*)

type proofs_verified = t

let of_int_exn (n : int) : t =
  if n < 0 then
    invalid_arg (Printf.sprintf "Proofs_verified.of_int_exn: got %d" n) ;
  n

let of_nat (n : _ Nat.t) : t = Nat.to_int n

let n0 : t = 0

let n1 : t = 1

let n2 : t = 2

let to_stable_v2 (x : t) : Stable.V2.t = x

let of_stable_v2 (x : Stable.V2.t) : t = of_int_exn x

(* [V1] is the encoding the Mina protocol accepts (ledger verification keys,
   side-loaded proofs). Keeping it narrow is deliberate: widening [V1] would be
   a protocol change, not a cleanup. Wider proofs travel only as [V2]. *)
let to_stable_v1 (x : t) : Stable.V1.t =
  match x with
  | 0 ->
      N0
  | 1 ->
      N1
  | 2 ->
      N2
  | n ->
      failwithf "Proofs_verified.to_stable_v1: %d proofs verified exceeds V1" n
        ()

let of_stable_v1 : Stable.V1.t -> t = Stable.V1.to_latest

(* The prefix mask is right-aligned: the [to_int t] set bits sit at the end of
   the vector, e.g. [1] over width 2 is [false; true]. This matches the
   convention used by the consumers (see [wrap_main.ml], which builds the mask
   with [ones_vector |> Vector.rev] and pads with [extend_front_exn]). *)
let to_bool_vec : 'n Nat.t -> proofs_verified -> (bool, 'n) Vector.t =
 fun n t ->
  let len = Nat.to_int n in
  Vector.init n ~f:(fun idx -> idx >= len - t)

let of_bool_vec (v : (bool, 'n) Vector.t) : proofs_verified =
  Vector.foldi (Vector.rev v) ~init:0 ~f:(fun idx count value ->
      if value then
        if idx = count then count + 1
        else
          invalid_arg
            "Prefix_mask.of_bool_vec: expected [false; false; ...; false; \
             true; ...; true; true]"
      else count )

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
               (t :> (Step_impl.Boolean.var, n Nat.N3.plus_n) Vector.t) )
           ~f:(fun b -> ((b :> Step_impl.Field.t), 1)) )
  end

  let to_input ~zero ~one (t : t) =
    if t > 2 then
      failwithf "Proofs_verified.One_hot.to_input: cannot encode %i in 3 bits" t
        () ;
    let one_hot = Array.init 3 ~f:(fun idx -> if idx = t then one else zero) in
    Random_oracle_input.Chunked.packeds (Array.map one_hot ~f:(fun b -> (b, 1)))

  let typ n : ('n Checked.t, proofs_verified) Step_impl.Typ.t =
    let module M = One_hot_vector.Make (Step_impl) in
    Step_impl.Typ.transport (M.typ n) ~there:Fn.id ~back:of_int_exn
end
