[%%import
"/src/config.mlh"]

open Ppxlib
open Asttypes
open Parsetree
open Longident
open Core

let seed = "CodaPedersenParams"

let random_bool = Crs.create ~seed

module Impl = Curve_choice.Tick0
module Group = Curve_choice.Tick_backend.Inner_curve

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
    (x * square x)
    + (Curve_choice.Tick_backend.Inner_curve.Coefficients.a * x)
    + Curve_choice.Tick_backend.Inner_curve.Coefficients.b
  in
  if Impl.Field.is_square y2 then
    let a, b = sqrt y2 in
    if random_bool () then (x, a) else (x, b)
  else random_point ()

let scalar_size_in_triples = Curve_choice.Tock_full.Field.size_in_bits / 4

let max_input_size_in_bits = 20000

let base_params =
  List.init
    (max_input_size_in_bits / (3 * scalar_size_in_triples))
    ~f:(fun _i -> Group.of_affine (random_point ()))

let sixteen_times x =
  x |> Group.double |> Group.double |> Group.double |> Group.double

let params =
  let powers g =
    let gg = Group.double g in
    (g, gg, Group.add g gg, Group.double gg)
  in
  let open Sequence in
  concat_map (of_list base_params) ~f:(fun x ->
      unfold ~init:x ~f:(fun g -> Some (powers g, sixteen_times g))
      |> Fn.flip take scalar_size_in_triples )
  |> to_list

let params_array = Array.of_list params

let affine_params_ast ~loc =
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  let arr =
    E.pexp_array
      (List.map params ~f:(fun (g1, g2, g3, g4) ->
           E.pexp_tuple
             (List.map [g1; g2; g3; g4] ~f:(fun g ->
                  (* g is a random point so this is safe. *)
                  let x, y = Group.to_affine_exn g in
                  E.pexp_tuple
                    [ estring (Impl.Field.to_string x)
                    ; estring (Impl.Field.to_string y) ] )) ))
  in
  let%expr conv (x, y) = (Tick0.Field.of_string x, Tick0.Field.of_string y) in
  Array.map
    (fun (g1, g2, g3, g4) -> (conv g1, conv g2, conv g3, conv g4))
    [%e arr]

let params_ast affine_params ~loc =
  let%expr conv = Tick_backend.Inner_curve.of_affine in
  Array.map
    (fun (g1, g2, g3, g4) -> (conv g1, conv g2, conv g3, conv g4))
    [%e affine_params]

let group_map_params =
  Group_map.Params.create
    (module Curve_choice.Tick0.Field)
    Curve_choice.Tick_backend.Inner_curve.Coefficients.{a; b}

let group_map_params_structure ~loc =
  let module T = struct
    type t = Curve_choice.Tick_backend.Field.t Group_map.Params.t
    [@@deriving bin_io_unversioned]
  end in
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  [%str
    let params =
      let module T = struct
        type t = Curve_choice.Tick_backend.Field.t Group_map.Params.t
        [@@deriving bin_io_unversioned]
      end in
      Binable.of_string
        (module T)
        [%e estring (Binable.to_string (module T) group_map_params)]]

let params_structure ~loc =
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  [%str
    open Curve_choice

    let affine = [%e affine_params_ast ~loc]

    let params = [%e params_ast [%expr affine] ~loc]]

let generate_ml_file filename structure =
  let fmt = Format.formatter_of_out_channel (Out_channel.create filename) in
  Pprintast.top_phrase fmt (Ptop_def (structure ~loc:Ppxlib.Location.none))

let () =
  generate_ml_file "pedersen_params.ml" params_structure ;
  generate_ml_file "group_map_params.ml" group_map_params_structure ;
  ignore (exit 0)
