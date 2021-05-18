open Core_kernel
open Js_of_ocaml

let mk_field (type t nat)
    (module Fp : Snarkette.Fields.Fp_intf with type t = t and type Nat.t = nat)
    =
  object%js (_self)
    val order = Fp.order

    val one = Fp.one

    val zero = Fp.zero

    method random = Fp.random ()

    method neg (x : Fp.t) = Fp.negate x

    method inv (x : Fp.t) = Fp.inv x

    method add (x : Fp.t) (y : Fp.t) = Fp.(x + y)

    method mul (x : Fp.t) (y : Fp.t) = Fp.(x * y)

    method sub (x : Fp.t) (y : Fp.t) = Fp.(x - y)

    method div (x : Fp.t) (y : Fp.t) = Fp.(x / y)

    method square (x : Fp.t) = Fp.square x

    method sqrt (x : Fp.t) = Fp.sqrt x

    method toString (x : Fp.t) = Fp.to_string x |> Js.string

    method ofString x = Js.to_string x |> Fp.of_string

    method ofInt x = Fp.of_int x

    method equal x y = Fp.equal x y |> Js.bool

    method pack xs =
      Js.to_array xs |> Array.map ~f:Js.to_bool |> Array.to_list |> Fp.of_bits |> Js.Opt.option

    method unpack x = Fp.to_bits x |> Array.of_list |> Array.map ~f:Js.bool |> Js.array
  end

let _ =
  let pasta_fp = mk_field (module Snarkette.Pasta.Fp) in
  let pasta_fq = mk_field (module Snarkette.Pasta.Fq) in
  Js.export "Pasta"
    (object%js (_self)
       val fp = pasta_fp

       val fq = pasta_fq
    end)
