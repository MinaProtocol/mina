open Core_kernel
open Ppxlib
open Ast_builder.Default

let expect_single_decl ~loc : type_declaration list -> type_declaration =
  function
  | [ type_decl ] ->
      type_decl
  | _ ->
      Location.raise_errorf ~loc "Expected a single type decl."

let extract_string_attrs (attributes : attributes) =
  List.filter_map attributes ~f:(fun (attr : attribute) ->
      match attr.attr_payload with
      | PStr
          [ { pstr_desc =
                Pstr_eval
                  ({ pexp_desc = Pexp_constant (Pconst_string (str, _)); _ }, _)
            ; _
            }
          ] ->
          Some (attr.attr_name.txt, str)
      | PStr [] ->
          Some (attr.attr_name.txt, "")
      | _ ->
          None)

let get_record_fields_exn (type_decl : type_declaration) =
  match type_decl.ptype_kind with
  | Ptype_record fields ->
      fields
  | _ ->
      Location.raise_errorf ~loc:type_decl.ptype_loc "Expected a record type."

let ann_str :
       loc:Location.t
    -> path:string
    -> rec_flag * type_declaration list
    -> structure =
 fun ~loc ~path:_ (_rec_flag, type_decls) ->
  let type_decl = expect_single_decl ~loc type_decls in
  let loc = type_decl.ptype_loc in
  let name = type_decl.ptype_name.txt ^ "_annots" in
  let fields = get_record_fields_exn type_decl in
  let field_branches =
    List.map fields ~f:(fun (field : label_declaration) ->
        let string_attributes = extract_string_attrs field.pld_attributes in
        Ppxlib.Ast_builder.Default.case
          ~lhs:(Ppxlib.Ast_builder.Default.pstring ~loc field.pld_name.txt)
          ~guard:None
          ~rhs:
            (Ppxlib.Ast_builder.Default.elist ~loc
               (List.map string_attributes ~f:(fun (attr_name, attr_value) ->
                    Ppxlib.Ast_builder.Default.pexp_tuple ~loc
                      [ Ppxlib.Ast_builder.Default.estring ~loc attr_name
                      ; Ppxlib.Ast_builder.Default.estring ~loc attr_value
                      ]))))
  in
  let field_branches =
    field_branches
    @ [ Ppxlib.Ast_builder.Default.case
          ~lhs:(Ppxlib.Ast_builder.Default.ppat_any ~loc)
          ~guard:None ~rhs:[%expr failwith "unknown field"]
      ]
  in
  [%str
    let [%p Ppxlib.Ast_builder.Default.pvar ~loc name] =
     fun str ->
      [%e Ppxlib.Ast_builder.Default.pexp_match ~loc [%expr str] field_branches]]

let ann_sig :
       loc:Location.t
    -> path:string
    -> rec_flag * type_declaration list
    -> signature =
 fun ~loc ~path:_ (_rec_flag, type_decls) ->
  let type_decl = expect_single_decl ~loc type_decls in
  let loc = type_decl.ptype_loc in
  let name = type_decl.ptype_name.txt ^ "_annots" in
  let type_ = [%type: string -> string] in
  [ psig_value ~loc
      (value_description ~loc ~name:(Located.mk ~loc name) ~type_ ~prim:[])
  ]

let ann =
  Deriving.add "ann"
    ~str_type_decl:(Deriving.Generator.make_noarg ann_str)
    ~sig_type_decl:(Deriving.Generator.make_noarg ann_sig)
