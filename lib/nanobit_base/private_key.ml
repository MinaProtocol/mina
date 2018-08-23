open Core_kernel
open Async_kernel

module T = struct
  type t = Snark_params.Tick.Inner_curve.Scalar.t [@@deriving bin_io, sexp]
end
include T

let create () =
  if Insecure.private_key_generation then
    Snark_params.Tick.Inner_curve.Scalar.random ()
  else failwith "Insecure.private_key_generation"

let gen =
  let open Bignum_bigint in
  Quickcheck.Generator.map
    (gen_incl one (Snark_params.Tick.Inner_curve.Scalar.size - one))
    ~f:Snark_params.Tock.Bigint.(Fn.compose to_field of_bignum_bigint)

let of_bigstring_exn = Binable.of_bigstring (module T)

let to_bigstring = Binable.to_bigstring (module T)

let to_base64 t =
  to_bigstring t
  |> Bigstring.to_string
  |> B64.encode

let of_base64_exn s =
  B64.decode s
  |> Bigstring.of_string
  |> of_bigstring_exn

