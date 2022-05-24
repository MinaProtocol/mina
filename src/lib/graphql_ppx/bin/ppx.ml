open Base
open Ppxlib

let (let*) x f = Result.bind x ~f

(* Declare possible attributes on record fields *)

let attr_subquery =
  Ppxlib.Attribute.declare "graphql2.subquery"
    Attribute.Context.label_declaration
    Ast_pattern.(single_expr_payload (pexp_constant (pconst_string __ __)))
    (fun str _ -> str)

let attr_field =
  Ppxlib.Attribute.declare "graphql2.field"
    Attribute.Context.pattern
    Ast_pattern.(ptyp __)
    Fn.id

(* The functor is used to factorize the loc parameter in all Ast_builder functions *)
module Make (B : Ast_builder.S) = struct
  let mkloc txt = {txt; loc=B.loc}
  let loc = B.loc

  (** Create the type:
   type ('kind, 'name) r =
      {
       res_kind: 'kind;
       res_name: 'name;
      }
  *)
  (* TODO: mutation fields *)
  module R_type = struct
    let type_name = "r"
    let field_prefix = "res_"

    let make fields params =
      let name = mkloc type_name in
      let params' = List.map params ~f:(fun p -> (p, Invariant)) in
      let make_r_field label typ =
        let name = mkloc (field_prefix ^ label.pld_name.txt) in
        B.label_declaration ~name ~mutable_:Immutable ~type_:typ
      in
      let kind = Ptype_record (List.map2_exn fields params ~f:make_r_field) in
      let td = B.type_declaration ~name ~cstrs:[]
          ~params:params' ~kind ~private_:Public ~manifest:None
      in
      B.pstr_type Recursive [td]
  end

  (* Create a core_type from a type name and optional type parameters *)
  let mkconstr ?(args=[]) name =
    let ident = Longident.parse name in
    let loc = mkloc ident in
    B.ptyp_constr loc args

  (** Create the type:
      type 'a modifier = 'a option
      if needed. In general, it is better to source it from the user.
  *)
  module Res_type = struct
    let type_name = "modifier"
    let make () =
      [%stri type 'a modifier = 'a option]
  end

  module Out_type = struct
    let type_name = "out"
    let make () =
      [%stri type out = t modifier]
  end

  (* Create the GADT type of the form:
   type _ query =
    Empty: (unit, unit, unit) r query
  | Address :
      {siblings: (unit, 'name, 'id) r query;
       subquery: 'a Address.Gql.query;
      } -> 
      ('a Address.Gql.res, 'name, 'id) r query
  | Name:
      {siblings : ('address, unit, 'id) r query;} ->
      ('address, string, 'id) r query

  | Id: {siblings: ('address, 'name, unit) r query}  ->
        ('address, 'name, int) r query
  *)
  module Query_type = struct
    let type_name = "query"
    let empty_field = "Empty"
    let siblings_name = "siblings"
    let subquery_name = "subquery"

    (* Create the result type of the gadt from the list of type params *)
    let mkres params =
      let res_r = mkconstr R_type.type_name ~args:params in
      mkconstr type_name ~args:[res_r]

    let make _td fields params =
      let name = mkloc type_name in
      let params' = [(B.ptyp_any, Invariant)] in
      let replace_var_by_type params to_replace replacement =
        List.map params ~f:(fun p ->
            if Poly.(p = to_replace) then replacement (* replace *)
            else p (* keep *)
          ) 
      in
      let type_of_module type_name mod_name =
        let var = B.ptyp_var "a" in
        let foreign_type = if String.is_empty mod_name then type_name
          else mod_name ^ "." ^ type_name
        in
        mkconstr foreign_type ~args:[var]
      in
      let make_r_constr label typ =
        let name = mkloc (String.capitalize label.pld_name.txt) in
        let res_type = match Attribute.get attr_subquery label with
          | None -> label.pld_type
          | Some mod_name -> type_of_module Res_type.type_name mod_name
        in
        (* Replace type variable of current field by the actual type when requested *)
        let res_params = replace_var_by_type params typ res_type in
        let res = Some (mkres res_params) in
        (* Type of the siblings field in the arg record *)
        let sibling_type =
          mkres (replace_var_by_type params typ ([%type: unit]))
        in
        (* Siblings field in the arg record *)
        let sibling_field =
          B.label_declaration ~name:(mkloc siblings_name) ~mutable_:Immutable
            ~type_:sibling_type
        in
        let args =
          match Attribute.get attr_subquery label with
          | None -> (* no subquery attribute *) Pcstr_record [sibling_field]
          | Some mod_name ->
            let typ = type_of_module type_name mod_name in
            let subquery_field =
              B.label_declaration ~name:(mkloc subquery_name)
                ~mutable_:Immutable ~type_:typ
            in
            Pcstr_record [sibling_field; subquery_field]
        in
        B.constructor_declaration ~name ~args ~res
      in
      (* Empty constructor, with only units *)
      let empty =
        let name = mkloc empty_field in
        let args = Pcstr_tuple [] in
        let res_params = List.map params ~f:(fun _ -> [%type: unit]) in
        let res = Some (mkres res_params) in
        B.constructor_declaration ~name ~args ~res
      in
      let constructors = empty :: (List.map2_exn fields params ~f:make_r_constr)
      in
      (* Assemble all *)
      let kind = Ptype_variant constructors in
      let typedecl = B.type_declaration ~name ~cstrs:[]
          ~params:params' ~kind ~private_:Public ~manifest:None in
      B.pstr_type Recursive [typedecl]
  end

  let opens =
    [
      [%stri open Graphql_utils.Wrapper.Make2(Graphql_async.Schema)]
    ]

  (* Derive a whole module from the type declaration *)
  let derive_type 
    (td : type_declaration) (rec_fields : label_declaration list)
    ~fields =
    ignore fields;
    (* Create type variables for each field of the record *)
    let params = List.map rec_fields ~f:(fun label -> B.ptyp_var label.pld_name.txt)
    in
    (* Create types *)
    let r_type = R_type.make rec_fields params in
    let res_type = Res_type.make () in
    let query_type = Query_type.make td rec_fields params in
    let out_type = Out_type.make () in
    let all_items = opens @ [r_type; res_type; out_type; query_type] in
    all_items


  (* Synthesis of a field declaration, after parsing *)
  type field_declaration = {
    name : string;
    typ_value : Ppxlib.expression;
    typ_annotation : Ppxlib.core_type;
    args : Ppxlib.expression;
    resolve : Ppxlib.expression
  }

  (** Generate the actual Graphql.field expression of a field *)
  let generate_field orig field =
    let name = B.estring field.name in
    let new_expr =
      [%expr field [%e name]
          ~typ:[%e field.typ_value]
          ~resolve:[%e field.resolve]
          ~args:[%e field.args]
      ]
    in
    {orig with pvb_expr = new_expr}

  (** Rewrite the Fields module, changing every attributed field by its proper
      generated expression *)
  let rewrite_fields_module fields modl =
    let in_declared name =
      List.find fields ~f:(fun x -> String.(x.name = name))
    in
    List.map modl ~f:(fun str_item ->
        let pstr_desc = 
          match str_item.pstr_desc with
          | Pstr_value (x, vbs) ->
            let vbs' = List.map vbs ~f:(fun vb ->
                begin match vb.pvb_pat.ppat_desc with
                  | Ppat_var {txt; _} ->
                    begin match in_declared txt with
                      | Some field -> generate_field vb field
                      | None -> vb
                    end
                  | _ -> vb
                end
              )
            in Pstr_value (x, vbs')
          | x -> x
        in {str_item with pstr_desc}
      )
    |> Result.return 

  (** Gather data from an expected field of the form:
      {obj = ...; typ = ...; args = ...; resolve = ...}
      TODO do not depend on order
      TODO proper error reporting if not matching
  *)
  let parse_field typ_annotation vb =
    match vb.pvb_pat.ppat_desc with
    | Ppat_var {txt; _} ->
      let name = txt in
      let loc = vb.pvb_loc in
      let expected = Ast_pattern.(
          (pexp_record
             ((loc (lident (string "typ")) ** __) ^::
              (loc (lident (string "args")) ** __) ^::
              (loc (lident (string "resolve")) ** __) ^::
              nil) none)
        )
      in
      let pack typ_value args resolve =
        Some {name; typ_value; typ_annotation; args; resolve}
      in
      Ast_pattern.parse expected loc vb.pvb_expr pack 
    | _ -> None (* should be a proper name *)

  (** Check that the Fields submodule defines a value for each field of the record *)
  let get_fields fields =
    (** Return the list of the names of values defined in a module. *)
    List.map fields ~f:(fun str_item ->
        match str_item.pstr_desc with
        | Pstr_value (_, vbs) ->
          List.filter_map vbs ~f:(fun vb ->
              match Attribute.get attr_field vb.pvb_pat with
              | Some typ -> parse_field typ vb
              | None -> None
            )
        | _ -> []
      )
    |> List.concat

  let gen_typ name (fields : field_declaration list) =
    let name = B.estring name in
    let field_list =
      List.map fields ~f:(fun f -> B.evar f.name)
      |> B.elist
    in
    [%stri let typ () = obj [%e name] ~fields:(fun _ -> Fields.([%e field_list]))]
end

let module_name = "Gql"

(* Detect deriver calls on record type declarations, and generate the derivation *)
let impl_generator name ~fields type_decl =
  let td = type_decl in
  let loc = td.ptype_loc in
  match td.ptype_kind with
  | Ptype_record rec_fields ->
    let fields_module = fields in
    let builder = Ast_builder.make loc in
    let module B = (val builder : Ast_builder.S) in
    let module T = Make(B) in
    let fields = T.get_fields fields_module in
    let derived_types = T.derive_type td rec_fields ~fields in
    let typ = T.gen_typ name fields in
    let* rewritten_fields = T.rewrite_fields_module fields fields_module in
    (* Make module with created items *)
    let all_items = derived_types @ rewritten_fields @ [typ] in
    let expr = B.pmod_structure all_items in
    let mkloc txt = {txt; loc} in
    let module_binding = B.module_binding ~name:(mkloc module_name) ~expr in
    Result.return [B.pstr_module module_binding]
  | _ -> Result.fail (loc, "Type t must be a record type.")

(** In a structure, find a type declaration for a type named [name] *)
let find_type structure name =
  let f str_item = match str_item.pstr_desc with
    | Pstr_type (_, tds) ->
      List.find tds ~f:(fun {ptype_name = {txt;_}; _} -> String.(txt = name))
    | _ -> None
  in
  List.find_map structure ~f

(** In a structure, find an explicit module declaration
 * for a module named [name] *)
let find_module structure name =
  let f str_item = match str_item.pstr_desc with
    | Pstr_module {pmb_name = {txt; _};
                   pmb_expr = {pmod_desc = Pmod_structure s; _} as e;
                   _ } when String.(txt = name) -> Some (e, s)
    | _ -> None
  in
  List.find_map structure ~f

(** Remove a named module from a structure *)
let remove_module structure name =
  let f str_item = match str_item.pstr_desc with
    | Pstr_module {pmb_name = {txt; _}; _ } when String.(txt = name) -> false
    | _ -> true
  in
  List.filter structure ~f

(** Check the payload is valid, and pass important parts to the generator.
    Returns the payload itself, plus the generated items *)
let ppx_entrypoint ~ctxt name payload =
  let module B = Ast_builder.Default in
  let loc = Expansion_context.Extension.extension_point_loc ctxt in
  let make_error loc msg =
    let ext =
      Location.Error.createf ~loc "%s" msg
      |> Location.Error.to_extension
    in
    B.pstr_extension ~loc ext []
  in
  let go () =
    let* (_, fields) = Result.of_option (find_module payload "Fields")
        ~error:(loc, "A submodule Fields is required in the module, but was not found.")
    in
    let payload_without_fields = remove_module payload "Fields" in
    let* type_decl = Result.of_option (find_type payload "t")
        ~error:(loc, "A base type t is required in the module, but was not found.")
    in
    let* generated_items = impl_generator name type_decl ~fields in
    let items = payload_without_fields @ generated_items in
    let expr = B.pmod_structure ~loc items in
    let binding = B.module_binding ~name:{loc; txt=name} ~expr ~loc in
    let final = B.pstr_module binding ~loc in
    Result.return final
  in match go () with
  | Ok x -> x
  | Error (loc, msg) -> make_error loc msg

let extension =
  Extension.V3.declare
    "derive_graphql"
    Extension.Context.structure_item
    Ast_pattern.(
      pstr ((pstr_module
               (module_binding ~name:__ ~expr:(pmod_structure __))
            ^:: nil))
    )
    ppx_entrypoint

let rule = Context_free.Rule.extension extension

(* Register the deriver *)
let graphql2_rewriter =
  Driver.register_transformation ~rules:[rule] "graphql2"
