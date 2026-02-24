open Core_kernel

let length_in_bits = 256

let length_in_bytes = length_in_bits / 8

[%%versioned
module Stable = struct
  module V1 = struct
    type t = Mina_stdlib.Bounded_types.String.Stable.V1.t
    [@@deriving sexp, equal, compare, hash, yojson]

    let to_latest = Fn.id

    module Base58_check = Base58_check.Make (struct
      let description = "Aux hash"

      let version_byte = Base58_check.Version_bytes.staged_ledger_hash_aux_hash
    end)

    let to_base58_check s = Base58_check.encode s

    let of_base58_check_exn s = Base58_check.decode_exn s

    let to_yojson s = `String (to_base58_check s)

    let of_yojson = function
      | `String s -> (
          match Base58_check.decode s with
          | Error e ->
              Error
                (sprintf "Aux_hash.of_yojson, bad Base58Check:%s"
                   (Error.to_string_hum e) )
          | Ok x ->
              Ok x )
      | _ ->
          Error "Aux_hash.of_yojson expected `String"
  end
end]

[%%define_locally
Stable.Latest.
  ( to_yojson
  , of_yojson
  , to_base58_check
  , of_base58_check_exn
  , compare
  , sexp_of_t )]

let of_bytes = Fn.id

let to_bytes = Fn.id

let dummy : t = String.init length_in_bytes ~f:(fun _ -> '\000')

let of_sha256 : Digestif.SHA256.t -> t =
  Fn.compose of_bytes Digestif.SHA256.to_raw_string

let gen : t Quickcheck.Generator.t =
  let char_generator =
    Base_quickcheck.Generator.of_list
      [ '0'
      ; '1'
      ; '2'
      ; '3'
      ; '4'
      ; '5'
      ; '6'
      ; '7'
      ; '8'
      ; '9'
      ; 'A'
      ; 'B'
      ; 'C'
      ; 'D'
      ; 'E'
      ; 'F'
      ]
  in
  String.gen_with_length (length_in_bytes * 2) char_generator
  |> Quickcheck.Generator.map ~f:(Fn.compose of_sha256 Digestif.SHA256.of_hex)
