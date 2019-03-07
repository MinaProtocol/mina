[%%import
"../../../config.mlh"]

open Ppxlib
open Asttypes
open Parsetree
open Longident
open Core
open Fold_lib

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

let scalar_size_in_triples = Crypto_params_init.Tock0.Field.size_in_bits / 4

let max_input_size_in_bits = 20000

let params =
  List.init
    (max_input_size_in_bits / (3 * scalar_size_in_triples))
    ~f:(fun i -> Group.of_affine_coordinates (random_point ()))

let sixteen_times x =
  x |> Group.double |> Group.double |> Group.double |> Group.double

let params_for_prover =
  let powers g =
    let gg = Group.double g in
    (g, gg, Group.add g gg, Group.double gg)
  in
  List.map params ~f:(fun x ->
      let rec go pt acc i =
        if i = scalar_size_in_triples then List.rev acc
        else go (sixteen_times pt) (powers pt :: acc) (i + 1)
      in
      go x [] 0 )
  |> List.concat

let params_array = Array.of_list params

let params_ast ~loc =
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  let earray =
    E.pexp_array
      (List.map params ~f:(fun g ->
           let x, y = Group.to_affine_coordinates g in
           E.pexp_tuple
             [ estring (Impl.Field.to_string x)
             ; estring (Impl.Field.to_string y) ] ))
  in
  let%expr conv (x, y) =
    Tick_backend.Inner_curve.of_affine_coordinates
      (Tick0.Field.of_string x, Tick0.Field.of_string y)
  in
  Array.map conv [%e earray]

let params_for_prover_ast ~loc =
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  let earray =
    E.pexp_array
      (List.map params_for_prover ~f:(fun (g1, g2, g3, g4) ->
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

let params_structure ~loc =
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  [%str
    open Crypto_params_init

    let params = [%e params_ast ~loc]

    let params_for_prover = [%e params_for_prover_ast ~loc]]

[%%if
defined fake_hash && fake_hash]

(* don't bother building table *)
let get_window_tables () = [||]

[%%else]

let get_window_tables () =
  Array.of_list_map params ~f:Group.Window_table.create

[%%endif]

let window_tables_ast ~loc =
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  let tables = get_window_tables () in
  estring
    (Binable.to_string
       ( module struct
         type t = Group.Window_table.t array [@@deriving bin_io]
       end )
       tables)

let window_tables_structure ~loc =
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  [%str
    open Core_kernel
    module Group = Crypto_params_init.Tick_backend.Inner_curve

    let window_tables_string_opt_ref = ref (Some [%e window_tables_ast ~loc])

    let window_tables =
      lazy
        (let s = Option.value_exn !window_tables_string_opt_ref in
         (* allow string to be GCed *)
         window_tables_string_opt_ref := None ;
         Binable.of_string
           ( module struct
             type t = Group.Window_table.t array [@@deriving bin_io]
           end )
           s)]

let generate_ml_file filename structure =
  let fmt = Format.formatter_of_out_channel (Out_channel.create filename) in
  Pprintast.top_phrase fmt (Ptop_def (structure ~loc:Ppxlib.Location.none))

let () =
  generate_ml_file "pedersen_params.ml" params_structure ;
  generate_ml_file "pedersen_window_tables.ml" window_tables_structure ;
  ignore (exit 0)
