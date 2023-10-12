(* protocol_version.ml *)

[%%import "/src/config.mlh"]

(* see RFC 0049 for details *)

open Core_kernel
module Wire_types = Mina_wire_types.Protocol_version

module Make_sig (A : Wire_types.Types.S) = struct
  module type S = Protocol_version_intf.Full with type Stable.V2.t = A.V2.t
end

module Make_str (A : Wire_types.Concrete) = struct
  [%%versioned
  module Stable = struct
    module V2 = struct
      type t = A.V2.t = { transaction : int; network : int; patch : int }
      [@@deriving compare, equal, sexp, yojson, fields, hash, annot]

      let to_latest = Fn.id
    end
  end]

  let create = Fields.create

  let of_string_exn s =
    let is_digit_string s = String.for_all s ~f:Char.is_digit in
    match String.split s ~on:'.' with
    | [ transaction; network; patch ] ->
        if
          not
            ( is_digit_string transaction
            && is_digit_string network && is_digit_string patch )
        then failwith "Unexpected nondigits in input" ;
        { transaction = Int.of_string transaction
        ; network = Int.of_string network
        ; patch = Int.of_string patch
        }
    | _ ->
        failwith
          "Protocol_version.of_string_exn: expected string of form nn.nn.nn"

  let of_string_opt s = try Some (of_string_exn s) with _ -> None

  let to_string t = sprintf "%u.%u.%u" t.transaction t.network t.patch

  [%%inject "current_transaction", protocol_version_transaction]

  [%%inject "current_network", protocol_version_network]

  [%%inject "current_patch", protocol_version_patch]

  let current =
    { transaction = current_transaction
    ; network = current_network
    ; patch = current_patch
    }

  let (proposed_protocol_version_opt : t option ref) = ref None

  let set_proposed_opt t_opt = proposed_protocol_version_opt := t_opt

  let get_proposed_opt () = !proposed_protocol_version_opt

  let compatible_with_daemon (t : t) =
    (* patch not considered for compatibility *)
    t.transaction = current.transaction && t.network = current.network

  (* when an external transition is deserialized, might contain
     negative numbers
  *)
  let is_valid t = t.transaction >= 1 && t.network >= 1 && t.patch >= 0

  let older_than_current t =
    transaction t < transaction current
    || (transaction t = transaction current && network t < network current)
    || transaction t = transaction current
       && network t = network current
       && patch t < patch current

  let gen =
    let open Quickcheck.Generator.Let_syntax in
    let%map transaction = Quickcheck.Generator.small_non_negative_int
    and network = Quickcheck.Generator.small_non_negative_int
    and patch = Quickcheck.Generator.small_non_negative_int in
    { transaction = transaction + 1; network = network + 1; patch }

  let deriver obj =
    let open Fields_derivers_zkapps.Derivers in
    let ( !. ) = ( !. ) ~t_fields_annots in
    Fields.make_creator obj ~transaction:!.int ~network:!.int ~patch:!.int
    |> finish "ProtocolVersion" ~t_toplevel_annots
end

module T = Wire_types.Make (Make_sig) (Make_str)
include T

module N = Mina_numbers.Nat.Make32 ()

type var =
  { transaction : N.Checked.t; network : N.Checked.t; patch : N.Checked.t }

module Checked = struct
  let to_input { transaction; network; patch } =
    Random_oracle.Input.Chunked.(
      append
        (append (N.Checked.to_input transaction) (N.Checked.to_input network))
        (N.Checked.to_input patch))

  let if_ cond ~(then_ : var) ~(else_ : var) =
    let open Snark_params.Tick in
    let%map transaction =
      N.Checked.if_ cond ~then_:then_.transaction ~else_:else_.transaction
    and network = N.Checked.if_ cond ~then_:then_.network ~else_:else_.network
    and patch = N.Checked.if_ cond ~then_:then_.patch ~else_:else_.network in
    { transaction; network; patch }

  let constant (t : t) =
    { transaction = N.Checked.constant (N.of_int (transaction t))
    ; network = N.Checked.constant (N.of_int (network t))
    ; patch = N.Checked.constant (N.of_int (patch t))
    }

  let current = constant current

  let equal_to_current t =
    let open Snark_params.Tick in
    let%bind transaction = N.Checked.equal t.transaction current.transaction
    and network = N.Checked.equal t.network current.network
    and patch = N.Checked.equal t.patch current.patch in
    Boolean.all [ transaction; network; patch ]

  let older_than_current t =
    let open Snark_params.Tick in
    let open N.Checked in
    let%bind transaction_older = t.transaction < current.transaction in
    let%bind transaction_equal = t.transaction = current.transaction in
    let%bind network_less = t.network < current.network in
    let%bind network_older = Boolean.(transaction_equal && network_less) in
    let%bind network_equal = t.network = current.network in
    let%bind patch_less = t.patch < current.patch in
    let%bind patch_older =
      Boolean.all [ transaction_equal; network_equal; patch_less ]
    in
    Boolean.any [ transaction_older; network_older; patch_older ]

  type t = var
end

open Snark_params

let typ : (Checked.t, t) Tick.Typ.t =
  Tick.Typ.tuple3 N.Checked.typ N.Checked.typ N.typ
  |> Tick.Typ.transport
       ~there:(fun t ->
         (N.of_int @@ transaction t, N.of_int @@ network t, N.of_int @@ patch t)
         )
       ~back:(fun (transaction, network, patch) ->
         T.create ~transaction:(N.to_int transaction)
           ~network:(N.to_int network) ~patch:(N.to_int patch) )
  |> Tick.Typ.transport_var
       ~there:(fun { transaction; network; patch } ->
         (transaction, network, patch) )
       ~back:(fun (transaction, network, patch) ->
         { transaction; network; patch } )

let to_input t =
  Random_oracle.Input.Chunked.(
    append
      (append
         (N.to_input (N.of_int (transaction t)))
         (N.to_input (N.of_int (network t))) )
      (N.to_input (N.of_int (patch t))))
