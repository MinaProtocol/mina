[%%import
"../../config.mlh"]

open Core_kernel
open Async_kernel
open Snark_params

[%%versioned_asserted
module Stable = struct
  module V1 = struct
    type t = Tick.Inner_curve.Scalar.t [@@deriving sexp]

    let to_latest = Fn.id

    let to_yojson t = `String (Tick.Inner_curve.Scalar.to_string t)

    let of_yojson = function
      | `String s ->
          Ok (Tick.Inner_curve.Scalar.of_string s)
      | _ ->
          Error "Private_key.of_yojson expected `String"

    let gen =
      let open Bignum_bigint in
      Quickcheck.Generator.map
        (gen_uniform_incl one (Snark_params.Tick.Inner_curve.Scalar.size - one))
        ~f:Snark_params.Tock.Bigint.(Fn.compose to_field of_bignum_bigint)
  end

  module Tests = struct end
end]

type t = Stable.Latest.t [@@deriving yojson, sexp]

[%%define_locally
Stable.Latest.(gen)]

let create () =
  (* This calls into libsnark which uses /dev/urandom *)
  Tick.Inner_curve.Scalar.random ()

let of_bigstring_exn = Binable.of_bigstring (module Stable.Latest)

let to_bigstring = Binable.to_bigstring (module Stable.Latest)

module Base58_check = Base58_check.Base58_check_new.Make (struct
  let description = "Private key"

  let version_byte = Base58_check.Version_bytes.private_key
end)

let to_base58_check t =
  Base58_check.encode (to_bigstring t |> Bigstring.to_string)

let of_base58_check_exn s =
  let decoded = Base58_check.decode_exn s in
  decoded |> Bigstring.of_string |> of_bigstring_exn
