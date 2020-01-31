[%%import
"/src/config.mlh"]

open Ppxlib
open Asttypes
open Parsetree
open Core

[%%if
proof_level = "full"]

let key_generation = true

[%%else]

let key_generation = false

[%%endif]

let pedersen_params ~loc =
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  let arr = Crypto_params.Pedersen_params.params in
  let arr_expr =
    List.init (Array.length arr) ~f:(fun i ->
        let g, _, _, _ = arr.(i) in
        estring
          (Binable.to_string
             (module Lite_curve_choice.Tock.G1)
             (Lite_compat_algebra.g1 g)) )
    |> E.pexp_array
  in
  [%expr
    Array.map
      (Core_kernel.Binable.of_string (module Lite_curve_choice.Tock.G1))
      [%e arr_expr]]

open Async

let main () =
  let fmt =
    Format.formatter_of_out_channel (Out_channel.create "pedersen_params.ml")
  in
  let loc = Ppxlib.Location.none in
  let structure =
    [%str let pedersen_params = lazy [%e pedersen_params ~loc]]
  in
  Pprintast.top_phrase fmt (Ptop_def structure) ;
  exit 0

let () =
  ignore (main ()) ;
  never_returns (Scheduler.go ())
