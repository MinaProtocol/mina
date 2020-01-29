open Core_kernel
open Async_kernel
open Snark_params

module Stable = struct
  module V1 = struct
    module T = struct
      type t = Tick.Inner_curve.Scalar.t
      [@@deriving bin_io, sexp, version {asserted}]

      let to_yojson t = `String (Tick.Inner_curve.Scalar.to_string t)
    end

    include T
  end

  module Latest = V1
end

type t = Stable.Latest.t [@@deriving to_yojson, sexp]

let create () =
  (* This calls into libsnark which uses /dev/urandom *)
  Tick.Inner_curve.Scalar.random ()

let gen =
  let open Bignum_bigint in
  Quickcheck.Generator.map
    (gen_uniform_incl one (Snark_params.Tick.Inner_curve.Scalar.size - one))
    ~f:Snark_params.Tock.Bigint.(Fn.compose to_field of_bignum_bigint)

let of_bigstring_exn = Binable.of_bigstring (module Stable.Latest)

let to_bigstring = Binable.to_bigstring (module Stable.Latest)

module Old_base58_check = Base58_check.Base58_check_old.Make (struct
  let description = "Private key"

  let version_byte = Base58_check.Version_bytes.private_key
end)

module New_base58_check = Base58_check.Base58_check_new.Make (struct
  let description = "Private key"

  let version_byte = Base58_check.Version_bytes.private_key
end)

let to_base58_check_old t =
  Old_base58_check.encode (to_bigstring t |> Bigstring.to_string)

let of_base58_check_old_exn s =
  let decoded = Old_base58_check.decode_exn s in
  decoded |> Bigstring.of_string |> of_bigstring_exn

let of_base58_check_new_exn s =
  let decoded = New_base58_check.decode_exn s in
  decoded |> Bigstring.of_string |> of_bigstring_exn

let to_base58_check = to_base58_check_old

let of_base58_check_exn s =
  try of_base58_check_old_exn s with _ -> of_base58_check_new_exn s
