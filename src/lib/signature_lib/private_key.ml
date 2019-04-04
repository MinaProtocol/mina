open Core_kernel
open Async_kernel
open Snark_params

module T = struct
  type t = Tick.Inner_curve.Scalar.t [@@deriving bin_io, sexp]
end

include T

let create () =
  (* This calls into libsnark which uses /dev/urandom *)
  Tick.Inner_curve.Scalar.random ()

let gen =
  let open Bignum_bigint in
  Quickcheck.Generator.map
    (gen_incl one (Snark_params.Tick.Inner_curve.Scalar.size - one))
    ~f:Snark_params.Tock.Bigint.(Fn.compose to_field of_bignum_bigint)

let of_bigstring_exn = Binable.of_bigstring (module T)

let to_bigstring = Binable.to_bigstring (module T)

let to_base64 t = to_bigstring t |> Bigstring.to_string |> Base64.encode_string

let of_base64_exn s =
  Base64.decode_exn s |> Bigstring.of_string |> of_bigstring_exn
