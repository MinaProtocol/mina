open Ppxlib
open Asttypes
open Parsetree
open Longident
open Core
open Async

let seed = "CodaPedersenParams"

let random_bool = Crs.create ~seed

module Impl = Crypto_params_init.Tick0
module Group = Crypto_params_init.Tick_backend.Inner_curve
open Tuple_lib

let bigint_of_bits bits =
  List.foldi bits ~init:Bigint.zero ~f:(fun i acc b ->
      if b then Bigint.(acc + (of_int 2 lsl i)) else acc )

let rec random_field_element () =
  let n =
    bigint_of_bits
      (List.init Impl.Field.size_in_bits ~f:(fun _ -> random_bool ()))
  in
  if Bigint.(n < Impl.Field.size) then
    Impl.Bigint.(to_field (of_bignum_bigint n))
  else random_field_element ()

let sqrt x =
  let a = Impl.Field.sqrt x in
  let b = Impl.Field.negate a in
  if Impl.Bigint.(compare (of_field a) (of_field b)) = -1 then (a, b)
  else (b, a)

(* y^2 = x^3 + a * x + b *)
let rec random_point () =
  let x = random_field_element () in
  let y2 =
    let open Impl.Field in
    let open Infix in
    (x * square x)
    + (Crypto_params_init.Tick_backend.Inner_curve.Coefficients.a * x)
    + Crypto_params_init.Tick_backend.Inner_curve.Coefficients.b
  in
  if Impl.Field.is_square y2 then
    let a, b = sqrt y2 in
    if random_bool () then (x, a) else (x, b)
  else random_point ()

let max_input_size = 20000

let params =
  List.init (max_input_size / 4) ~f:(fun i ->
      let t = Group.of_affine_coordinates (random_point ()) in
      let tt = Group.double t in
      (t, tt, Group.add t tt, Group.double tt) )

let params ~loc =
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  let earray =
    E.pexp_array
      (List.map params ~f:(fun (g1, g2, g3, g4) ->
           E.pexp_tuple
             (List.map [g1; g2; g3; g4] ~f:(fun g ->
                  let x, y = Group.to_affine_coordinates g in
                  E.pexp_tuple
                    [ estring (Impl.Field.to_string x)
                    ; estring (Impl.Field.to_string y) ] )) ))
  in
  let%expr conv (x, y) =
    Tick_backend.Inner_curve.of_affine_coordinates
      (Tick0.Field.of_string x, Tick0.Field.of_string y)
  in
  Array.map
    (fun (g1, g2, g3, g4) -> (conv g1, conv g2, conv g3, conv g4))
    [%e earray]

let structure ~loc =
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  [%str open Crypto_params_init

        let params = [%e params ~loc]]

let main () =
  let fmt =
    Format.formatter_of_out_channel (Out_channel.create "pedersen_params.ml")
  in
  Pprintast.top_phrase fmt (Ptop_def (structure ~loc:Ppxlib.Location.none)) ;
  exit 0

let () =
  ignore (main ()) ;
  never_returns (Scheduler.go ())
