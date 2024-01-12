[%%import "/src/config.mlh"]

open Core_kernel
open Snark_params.Tick

[%%versioned
module Stable = struct
  module V1 = struct
    [@@@with_all_version_tags]

    type t = (Inner_curve.Scalar.t[@version_asserted])
    [@@deriving compare, sexp]

    (* deriver not working, apparently *)
    let sexp_of_t = [%sexp_of: Inner_curve.Scalar.t]

    let t_of_sexp = [%of_sexp: Inner_curve.Scalar.t]

    let to_latest = Fn.id

    [%%ifdef consensus_mechanism]

    let gen =
      let open Snark_params.Tick.Inner_curve.Scalar in
      let upperbound = Bignum_bigint.(pred size |> to_string) |> of_string in
      gen_uniform_incl one upperbound

    [%%else]

    let gen = Inner_curve.Scalar.(gen_uniform_incl one (zero - one))

    [%%endif]
  end
end]

[%%define_locally Stable.Latest.(gen)]

[%%ifdef consensus_mechanism]

let create () =
  (* This calls into libsnark which uses /dev/urandom *)
  Inner_curve.Scalar.random ()

[%%else]

let create () : t =
  let open Js_of_ocaml in
  let random_bytes_32 =
    Js.Unsafe.js_expr
      {js|(function() {
        var topLevel = (typeof self === 'object' && self.self === self && self) ||
          (typeof global === 'object' && global.global === global && global) ||
          this;
        var b;

        if (topLevel.crypto && topLevel.crypto.getRandomValues) {
          b = new Uint8Array(32);
          topLevel.crypto.getRandomValues(b);
        } else {
          if (typeof require === 'function') {
            var crypto = require('crypto');
            if (!crypto) {
              throw 'random values not available'
            }
            b = crypto.randomBytes(32);
          } else {
            throw 'random values not available'
          }
        }
        var res = [];
        for (var i = 0; i < 32; ++i) {
          res.push(b[i]);
        }
        res[31] &= 0x3f;
        return res;
      })|js}
  in
  let x : int Js.js_array Js.t = Js.Unsafe.fun_call random_bytes_32 [||] in
  let byte_undefined () = failwith "byte undefined" in
  Snarkette.Pasta.Fq.of_bigint
    (Snarkette.Nat.of_bytes
       (String.init 32 ~f:(fun i ->
            Char.of_int_exn (Js.Optdef.get (Js.array_get x i) byte_undefined) )
       ) )

[%%endif]

include Comparable.Make_binable (Stable.Latest)

(* for compatibility with existing private key serializations *)
let of_bigstring_exn =
  Binable.of_bigstring (module Stable.Latest.With_all_version_tags)

let to_bigstring =
  Binable.to_bigstring (module Stable.Latest.With_all_version_tags)

module Base58_check = Base58_check.Make (struct
  let description = "Private key"

  let version_byte = Base58_check.Version_bytes.private_key
end)

let to_base58_check t =
  Base58_check.encode (to_bigstring t |> Bigstring.to_string)

let of_base58_check_exn s =
  let decoded = Base58_check.decode_exn s in
  decoded |> Bigstring.of_string |> of_bigstring_exn

let sexp_of_t t = to_base58_check t |> Sexp.of_string

let t_of_sexp sexp = Sexp.to_string sexp |> of_base58_check_exn

let to_yojson t = `String (to_base58_check t)

let of_yojson = function
  | `String x -> (
      try Ok (of_base58_check_exn x) with
      | Failure str ->
          Error str
      | exn ->
          Error ("Signature_lib.Private_key.of_yojson: " ^ Exn.to_string exn) )
  | _ ->
      Error "Signature_lib.Private_key.of_yojson: Expected a string"
