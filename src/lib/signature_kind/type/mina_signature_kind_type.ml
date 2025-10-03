open Core_kernel

type t = Testnet | Mainnet | Other_network of string
[@@deriving bin_io_unversioned, equal]

(* Custom JSON serializers to serialize variants as lowercase strings *)
let to_yojson = function
  | Testnet ->
      `String "testnet"
  | Mainnet ->
      `String "mainnet"
  | Other_network name ->
      `String name

let of_yojson = function
  | `String "testnet" ->
      Ok Testnet
  | `String "mainnet" ->
      Ok Mainnet
  | `String name ->
      Ok (Other_network name)
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
