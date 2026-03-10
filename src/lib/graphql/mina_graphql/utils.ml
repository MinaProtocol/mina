open Core
open Mina_base

let get_ledger_and_breadcrumb mina =
  mina |> Mina_lib.best_tip |> Participating_state.active
  |> Option.map ~f:(fun tip ->
         ( Transition_frontier.Breadcrumb.staged_ledger tip
           |> Staged_ledger.ledger
         , tip ) )

let result_of_exn f v ~error = try Ok (f v) with _ -> Error error

(** Convert a GraphQL constant to the equivalent json representation.
    We can't coerce this directly because of the presence of the [`Enum]
    constructor, so we have to recurse over the structure replacing all of the
    [`Enum]s with [`String]s.
*)
let rec to_yojson (json : Graphql_parser.const_value) : Yojson.Safe.t =
  match json with
  | `Assoc fields ->
      `Assoc (List.map fields ~f:(fun (name, json) -> (name, to_yojson json)))
  | `Bool b ->
      `Bool b
  | `Enum s ->
      `String s
  | `Float f ->
      `Float f
  | `Int i ->
      `Int i
  | `List l ->
      `List (List.map ~f:to_yojson l)
  | `Null ->
      `Null
  | `String s ->
      `String s

let account_of_id id ledger =
  Mina_ledger.Ledger.location_of_account ledger id
  |> Option.value_exn
  |> Mina_ledger.Ledger.get ledger
  |> Option.value_exn

let account_of_kp (kp : Signature_lib.Keypair.t) ledger =
  account_of_id (Account_id.of_public_key kp.public_key) ledger
