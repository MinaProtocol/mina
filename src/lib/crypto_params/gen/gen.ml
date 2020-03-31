[%%import
"/src/config.mlh"]

open Ppxlib
open Asttypes
open Parsetree
open Longident
open Core
open Chunked_triples

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
    ~a:Curve_choice.Tick_backend.Inner_curve.Coefficients.a
    ~b:Curve_choice.Tick_backend.Inner_curve.Coefficients.b

let group_map_params_structure ~loc =
  let module T = struct
    type t = Curve_choice.Tick_backend.Field.t Group_map.Params.Stable.V1.t
    [@@deriving bin_io]
  end in
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  [%str
    let params =
      let module T = struct
        type t = Curve_choice.Tick_backend.Field.t Group_map.Params.t
        [@@deriving bin_io]
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

(* for the reversed chunk with value n, compute its curve value
   start is the starting parameter position of the chunk, based
    on its position in a list of chunks
*)
let compute_chunk_value ~start n =
  let chunk = List.rev (Chunk.of_int n) in
  let acc, _ =
    List.fold chunk ~init:(Group.zero, 0) ~f:(fun (acc, i) triple ->
        let term =
          Snarky.Pedersen.local_function ~negate:Group.negate
            params_array.(start + i)
            triple
        in
        (Group.add acc term, i + 1) )
  in
  acc

(* for each chunk boundary, 0, size, 2 * size, ..., num parameters / size
     for each possible chunk (2 ** (size * 3) of them)
       store its value in the array
*)

[%%if
defined fake_hash && fake_hash]

(* don't bother building table *)
let get_chunk_table () = [||]

[%%else]

let get_chunk_table () =
  let num_params = Array.length params_array in
  let max_chunks = num_params / Chunk.size in
  let rec loop ~chunk arrays =
    if chunk >= max_chunks then Array.of_list (List.rev arrays)
    else
      (* max_int + 1, because we need an entry for 0 *)
      let array = Array.create ~len:(Chunk.max_int + 1) Group.zero in
      for n = 0 to Chunk.max_int do
        array.(n) <- compute_chunk_value ~start:(chunk * Chunk.size) n
      done ;
      loop ~chunk:(chunk + 1) (array :: arrays)
  in
  let result = loop ~chunk:0 [] in
  result

[%%endif]

(* the AST representation of the chunk table is its string serialization
   - an AST for the table itself, using string representations of
      Field pairs, as is done for the params, is too large, causing
      ocamlopt to segfault
  - Binable.to_string is slow, and Marshal.to_string is much faster,
      but I (@psteckler) observed segfaults on deserialization for
      the latter
 *)
let chunk_table_ast ~loc =
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  let chunk_table = Chunk_table.create (get_chunk_table ()) in
  let chunk_table_string =
    Binable.to_string (module Chunk_table) chunk_table
  in
  estring chunk_table_string

let chunk_table_structure ~loc =
  let module E = Ppxlib.Ast_builder.Make (struct
    let loc = loc
  end) in
  let open E in
  [%str
    open Core
    module Group = Curve_choice.Tick_backend.Inner_curve

    let chunk_table =
      lazy
        (let s = [%e chunk_table_ast ~loc] in
         let t = Binable.of_string (module Chunk_table) s in
         t.table_data)]

let generate_ml_file filename structure =
  let fmt = Format.formatter_of_out_channel (Out_channel.create filename) in
  Pprintast.top_phrase fmt (Ptop_def (structure ~loc:Ppxlib.Location.none))

let () =
  generate_ml_file "pedersen_params.ml" params_structure ;
  generate_ml_file "pedersen_chunk_table.ml" chunk_table_structure ;
  generate_ml_file "group_map_params.ml" group_map_params_structure ;
  ignore (exit 0)
