open Base
open Ppxlib

let deriver_name = "to_enum"

let mangle ~suffix name =
  if String.equal name "t" then suffix else name ^ "_" ^ suffix

let mangle_lid ~suffix lid =
  match lid with
  | Lident name ->
      Lident (mangle ~suffix name)
  | Ldot (lid, name) ->
      Ldot (lid, mangle ~suffix name)
  | Lapply _ ->
      assert false

let mangle_prefix ~prefix name =
  if String.equal name "t" then prefix else prefix ^ "_" ^ name

let mangle_prefix_lid ~prefix lid =
  match lid with
  | Lident name ->
      Lident (mangle_prefix ~prefix name)
  | Ldot (lid, name) ->
      Ldot (lid, mangle_prefix ~prefix name)
  | Lapply _ ->
      assert false

let mk_lid name = Loc.make ~loc:name.loc (Longident.Lident name.txt)

let constr_of_decl ~loc decl =
  Ast_builder.Default.ptyp_constr ~loc (mk_lid decl.ptype_name)
    (List.map ~f:fst decl.ptype_params)

let str_decl ~loc (decl : type_declaration) : structure =
  let open Ast_builder.Default in
  match decl with
  | {ptype_kind= Ptype_variant constrs; ptype_name= name; _} ->
      (* [type t = A of int | B of bool | ...] *)
      [%str
        let ([%p pvar ~loc (mangle ~suffix:deriver_name name.txt)] :
              [%t constr_of_decl ~loc decl] -> int) =
          [%e
            pexp_function ~loc
              (List.mapi constrs ~f:(fun i constr ->
                   { pc_lhs=
                       ppat_construct ~loc (mk_lid constr.pcd_name)
                         ( match constr.pcd_args with
                         | Pcstr_tuple [] ->
                             None
                         | _ ->
                             Some (ppat_any ~loc) )
                   ; pc_guard= None
                   ; pc_rhs= eint ~loc i } ))]

        let [%p pvar ~loc (mangle_prefix ~prefix:"min" name.txt)] = 0

        let [%p pvar ~loc (mangle_prefix ~prefix:"max" name.txt)] =
          [%e eint ~loc (List.length constrs - 1)]]
  | { ptype_kind= Ptype_abstract
    ; ptype_name= name
    ; ptype_manifest= Some {ptyp_desc= Ptyp_constr (lid, _); _}
    ; _ } ->
      (* [type t = Foo.t] *)
      [%str
        let ([%p pvar ~loc (mangle ~suffix:deriver_name name.txt)] :
              [%t constr_of_decl ~loc decl] -> int) =
          [%e
            pexp_ident ~loc (Located.map (mangle_lid ~suffix:deriver_name) lid)]

        let [%p pvar ~loc (mangle_prefix ~prefix:"min" name.txt)] =
          [%e
            pexp_ident ~loc (Located.map (mangle_prefix_lid ~prefix:"min") lid)]

        let [%p pvar ~loc (mangle_prefix ~prefix:"max" name.txt)] =
          [%e
            pexp_ident ~loc (Located.map (mangle_prefix_lid ~prefix:"max") lid)]]
  | { ptype_kind= Ptype_abstract
    ; ptype_name= name
    ; ptype_manifest= Some {ptyp_desc= Ptyp_variant (constrs, Closed, _); _}
    ; _ } ->
      (* [type t = [ `A of int | `B of bool | ...]] *)
      [%str
        let ([%p pvar ~loc (mangle ~suffix:deriver_name name.txt)] :
              [%t constr_of_decl ~loc decl] -> int) =
          [%e
            pexp_function ~loc
              (List.mapi constrs ~f:(fun i constr ->
                   match constr with
                   | Rtag (label, _, has_empty, args) ->
                       { pc_lhs=
                           ( match (has_empty, args) with
                           | _, [] ->
                               (* [`A] *)
                               ppat_variant ~loc label.txt None
                           | false, _ :: _ ->
                               (* [`A of int] *)
                               ppat_variant ~loc label.txt
                                 (Some (ppat_any ~loc))
                           | true, _ :: _ ->
                               (* [`A | `A of int] *)
                               ppat_or ~loc
                                 (ppat_variant ~loc label.txt None)
                                 (ppat_variant ~loc label.txt
                                    (Some (ppat_any ~loc))) )
                       ; pc_guard= None
                       ; pc_rhs= eint ~loc i }
                   | Rinherit typ ->
                       Location.raise_errorf ~loc:typ.ptyp_loc
                         "Cannot derive %s for this type: inherited fields \
                          are not supported"
                         deriver_name ))]

        let [%p pvar ~loc (mangle_prefix ~prefix:"min" name.txt)] = 0

        let [%p pvar ~loc (mangle_prefix ~prefix:"max" name.txt)] =
          [%e eint ~loc (List.length constrs - 1)]]
  | _ ->
      Location.raise_errorf ~loc
        "Cannot derive %s for this type: must be explicit constructors, an \
         alias to a named path, or a closed variant type"
        deriver_name

let sig_decl ~loc (decl : type_declaration) : signature =
  let open Ast_builder.Default in
  List.map ~f:(psig_value ~loc)
    [ value_description ~loc ~prim:[]
        ~name:
          (Located.mk ~loc (mangle ~suffix:deriver_name decl.ptype_name.txt))
        ~type_:[%type: [%t constr_of_decl ~loc decl] -> int]
    ; value_description ~loc ~prim:[]
        ~name:
          (Located.mk ~loc (mangle_prefix ~prefix:"min" decl.ptype_name.txt))
        ~type_:[%type: int]
    ; value_description ~loc ~prim:[]
        ~name:
          (Located.mk ~loc (mangle_prefix ~prefix:"max" decl.ptype_name.txt))
        ~type_:[%type: int] ]

let str_type_decl ~loc ~path:_ (_rec_flag, decls) : structure =
  List.concat_map ~f:(str_decl ~loc) decls

let sig_type_decl ~loc ~path:_ (_rec_flag, decls) : signature =
  List.concat_map ~f:(sig_decl ~loc) decls

let deriver =
  Deriving.add
    ~str_type_decl:(Deriving.Generator.make_noarg str_type_decl)
    ~sig_type_decl:(Deriving.Generator.make_noarg sig_type_decl)
    deriver_name
