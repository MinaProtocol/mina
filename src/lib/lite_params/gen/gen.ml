[%%import
"../../../config.mlh"]

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

module Make (L : sig
  val loc : location
end) =
struct
  module E = Ppxlib.Ast_builder.Make (L)
  open E

  let string_expr m x = estring (Base64.encode_string (Binable.to_string m x))

  let g_string_expr g =
    string_expr (module Lite_curve_choice.Tock.G1) (Lite_compat_algebra.g1 g)

  let un_g_expr s_expr =
    [%expr
      Core_kernel.Binable.of_string
        (module Lite_curve_choice.Tock.G1)
        (Base64.decode_exn [%e s_expr])]

  let pedersen_params =
    let arr = Crypto_params.Pedersen_params.params in
    let arr_expr =
      List.init (Array.length arr) ~f:(fun i ->
          let g, _, _, _ = arr.(i) in
          g_string_expr g )
      |> E.pexp_array
    in
    [%expr Array.map (fun s -> [%e un_g_expr [%expr s]]) [%e arr_expr]]

  let group_map_params =
    let e =
      string_expr
        ( module struct
          type t = Lite_curve_choice.Tock.Fq.t Group_map.Params.t
          [@@deriving bin_io]
        end )
        (Group_map.Params.map Crypto_params.Group_map_params.params
           ~f:Lite_compat_algebra.field)
    in
    [%expr
      Core_kernel.Binable.of_string
        ( module struct
          type t = Lite_curve_choice.Tock.Fq.t Group_map.Params.t
          [@@deriving bin_io]
        end )
        (Base64.decode_exn [%e e])]

  let bowe_gabizon_hash_prefix_acc =
    un_g_expr
      (g_string_expr
         (Snark_params.Tick.Pedersen.State.salt Hash_prefixes.bowe_gabizon_hash)
           .acc)
end

open Async

let main () =
  let fmt =
    Format.formatter_of_out_channel
      (Out_channel.create "precomputed_params.ml")
  in
  let loc = Ppxlib.Location.none in
  let module E = Make (struct
    let loc = loc
  end) in
  let open E in
  let structure =
    [%str
      let pedersen_params = [%e pedersen_params]

      let group_map_params = [%e group_map_params]

      let bowe_gabizon_hash_prefix_acc = [%e bowe_gabizon_hash_prefix_acc]]
  in
  Pprintast.top_phrase fmt (Ptop_def structure) ;
  exit 0

let () =
  ignore (main ()) ;
  never_returns (Scheduler.go ())
