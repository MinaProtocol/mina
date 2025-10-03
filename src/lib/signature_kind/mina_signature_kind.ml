open Core_kernel

[%%versioned
module Stable = struct
  module V1 = struct
    type t =
      | Testnet
      | Mainnet
      | Other_network of Mina_stdlib.Bounded_types.String.Stable.V1.t
    [@@deriving equal]

    let to_latest = Fn.id
  end
end]

let to_string = function
  | Testnet ->
      "testnet"
  | Mainnet ->
      "mainnet"
  | Other_network name ->
      String.lowercase name

(* Custom JSON serializers to serialize variants as lowercase strings *)
let to_yojson = function
  | Testnet ->
      `String "testnet"
  | Mainnet ->
      `String "mainnet"
  | Other_network name ->
      `String name

let of_string s =
  match String.lowercase s with
  | "mainnet" ->
      Mainnet
  | "testnet" ->
      Testnet
  | other ->
      Other_network other

let of_yojson = function
  | `String s ->
      Ok (of_string s)
  | _ ->
      Error "Signature_kind must be a string"

(** Generator for random signature kinds. It takes a seed as a parameter for
    generating random strings. *)
let signature_kind_gen seed =
  let open Quickcheck.Generator.Let_syntax in
  let%bind choice = Int.gen_incl 0 2 in
  match choice with
  | 1 ->
      return Testnet
  | 2 ->
      return Mainnet
  | _ ->
      let gen = Base_quickcheck.Generator.string in
      let random_string = Quickcheck.random_value ~seed gen in
      return (Other_network random_string)

let%test_module "Signature_kind JSON serialization" =
  ( module struct
    let%test "mainnet serializes to lowercase string" =
      match to_yojson Mainnet with `String "mainnet" -> true | _ -> false

    let%test "testnet serializes to lowercase string" =
      match to_yojson Testnet with `String "testnet" -> true | _ -> false

    let%test "other_network serializes to its name" =
      match to_yojson (Other_network "custom_network") with
      | `String "custom_network" ->
          true
      | _ ->
          false

    let%test "mainnet round-trip" =
      equal Mainnet @@ Result.ok_or_failwith (of_yojson (to_yojson Mainnet))

    let%test "testnet round-trip" =
      equal Testnet @@ Result.ok_or_failwith (of_yojson (to_yojson Testnet))

    let%test "other_network round-trip" =
      equal (Other_network "my_network")
      @@ Result.ok_or_failwith
           (of_yojson (to_yojson (Other_network "my_network")))
  end )
