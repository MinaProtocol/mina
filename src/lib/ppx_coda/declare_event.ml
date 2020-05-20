(* declare_event.ml -- ppx to declare log events *)

(* Example usage:

   [%declare_event (Received_block,"Received blocks $blocks from $node",[(blocks: string list); (node : string); (height : int)]]

   which expands to:

   let received_block_event =
    { name = "Received_block"
    ; message = "Received block from $node"
    ; medata = [("blocks",["string"; "list"];("node",["string"]);("height",["int"])]
    ; id = ... (* SHA1 hash of name (20-character string) *)
    }

   Note:

    - the types in the metadata are a space-separated sequence of type constructors; the generated types are lists

    - the metadata list is optional

*)

open Core_kernel
open Ppxlib
open Asttypes

let name = "declare_event"

let print_hash hash =
  printf "\"" ;
  String.iter hash ~f:(fun c -> printf "\\x%02X" (Char.to_int c)) ;
  printf "\"\n%!"

let calc_name_hash name =
  let open Digestif.SHA256 in
  let ctx0 = init () in
  let ctx1 = feed_string ctx0 name in
  get ctx1 |> to_raw_string

let rec make_type_list = function
  | {ptyp_desc= Ptyp_constr ({txt= Lident type_name; _}, core_types); _} ->
      List.rev (type_name :: List.concat_map core_types ~f:make_type_list)
  | ty ->
      Location.raise_errorf ~loc:ty.ptyp_loc "Expected type constructor"

let get_constraint_desc = function
  | { pexp_desc=
        Pexp_constraint
          ({pexp_desc= Pexp_ident {txt= Lident id; _}; _}, core_type)
    ; _ } ->
      (id, make_type_list core_type)
  | exp ->
      Location.raise_errorf ~loc:exp.pexp_loc
        "Expected constrained type, where the type is named by an identifier"

let get_name_message_hash ~name ~message =
  let name_str =
    match name.pexp_desc with
    | Pexp_construct ({txt= Lident id; _}, None) ->
        id
    | _ ->
        Location.raise_errorf ~loc:name.pexp_loc "Expected constructor"
  in
  let message_str =
    match message.pexp_desc with
    | Pexp_constant (Pconst_string (msg, None)) ->
        msg
    | _ ->
        Location.raise_errorf ~loc:name.pexp_loc "Expected string constant"
  in
  let hash = calc_name_hash name_str in
  (name_str, message_str, hash)

let list_of_metadata metadata =
  let rec loop md acc =
    match md.pexp_desc with
    | Pexp_construct
        ({txt= Lident "::"; _}, Some {pexp_desc= Pexp_tuple [exp; rest]; _}) ->
        loop rest (exp :: acc)
    | Pexp_construct ({txt= Lident "[]"; _}, None) ->
        List.rev acc
    | _ ->
        Location.raise_errorf ~loc:metadata.pexp_loc
          "Expected a list of (item : type) pairs for metadata"
  in
  loop metadata []

let make_stri ~loc ~name_str ~message_str ~metadata_pairs ~hash =
  let (module Ast_builder) = Ast_builder.make loc in
  let open Ast_builder in
  let metadata =
    List.map metadata_pairs ~f:(fun (item, types) ->
        let type_exprs = List.map types ~f:estring in
        pexp_tuple [estring item; elist type_exprs] )
  in
  let event_name = String.lowercase name_str ^ "_event" in
  [%stri
    let [%p pvar event_name] =
      { name= [%e estring name_str]
      ; message= [%e estring message_str]
      ; metadata= [%e elist metadata]
      ; id= [%e estring hash] }]

let expand ~loc ~path:_ exprs =
  match exprs with
  | [name; message] ->
      (* explicitly, no metadata *)
      let name_str, message_str, hash = get_name_message_hash ~name ~message in
      make_stri ~loc ~name_str ~message_str ~metadata_pairs:[] ~hash
  | [name; message; metadata] ->
      let name_str, message_str, hash = get_name_message_hash ~name ~message in
      let metadata_list = list_of_metadata metadata in
      let metadata_pairs = List.map metadata_list ~f:get_constraint_desc in
      make_stri ~loc ~name_str ~message_str ~metadata_pairs ~hash
  | _ ->
      Location.raise_errorf ~loc
        "Expected a tuple of name (a constructor), message (string constant), \
         and optional metadata (list of (identifier : type))"

let ext =
  Extension.declare name Extension.Context.structure_item
    Ast_pattern.(single_expr_payload (pexp_tuple __))
    expand

let () =
  Driver.register_transformation name ~rules:[Context_free.Rule.extension ext]
