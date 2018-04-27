open Core

module Stable = struct
  module V1 = struct
    module T = struct
      type t = Bignum.Bigint.t * Bignum.Bigint.t
      [@@deriving eq, compare, hash]
      let sexp_of_t (x,y) =
        let sexp_of_bignum_abbrev x =
          let str =
            (Bignum.Bigint.to_string x)
          in
          let first_10 = String.slice str 0 (Int.min 10 (String.length str)) in
          let patched =
            if (String.length first_10 < String.length str) then
              first_10 ^ ".."
            else
              first_10
          in
          String.sexp_of_t patched
        in
        Sexp.List [ sexp_of_bignum_abbrev x ; sexp_of_bignum_abbrev y ]

      let t_of_sexp s =
        match s with
        | Sexp.Atom _ -> failwith "Invalid sexp"
        | Sexp.List [ x ; y ] ->
          (Bignum.Bigint.t_of_sexp x, Bignum.Bigint.t_of_sexp y)
        | Sexp.List _ -> failwith "Invalid sexp"
    end
    type t = Bignum.Bigint.Stable.V1.t * Bignum.Bigint.Stable.V1.t
    [@@deriving bin_io]
    let equal = T.equal

    include (T : (module type of T with type t := t))
  end
end

include Stable.V1

open Snark_params.Tick

type var = Boolean.var list * Boolean.var list
let typ : (var, t) Typ.t = Schnorr.Signature.typ
