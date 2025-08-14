open Core_kernel

type t = Testnet | Mainnet | Other_network of string
[@@deriving bin_io_unversioned, to_yojson]

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
