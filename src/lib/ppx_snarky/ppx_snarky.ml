open Longident
open Ast_helper
open Asttypes
open Parsetree

let deriver = "snarky"

let snarky_typ_path base = Location.mknoloc (Ldot (Lident "Typ", base))

let rec exp_of_type ~options ~path typ =
  ignore options ;
  ignore path ;
  match typ.ptyp_desc with
  | Ptyp_constr (ident, []) -> (
    match ident.txt with
    | Ldot (path, base) ->
        if String.equal base "t" || String.equal base "var" then
          Exp.ident (Location.mknoloc (Ldot (path, "typ")))
        else
          Ppx_deriving.raise_errorf ~loc:typ.ptyp_loc
            "Found neither t nor var."
    | Lident _ -> Ppx_deriving.raise_errorf ~loc:typ.ptyp_loc "Found Lident."
    | Lapply _ -> Ppx_deriving.raise_errorf ~loc:typ.ptyp_loc "Found Lapply." )
  | Ptyp_tuple typs ->
      let fun_arg typ = (Nolabel, exp_of_type ~options ~path typ) in
      let rec fold_tuple typs =
        match typs with
        | [typ1; typ2] ->
            Exp.apply
              (Exp.ident (snarky_typ_path "*"))
              (List.map fun_arg [typ1; typ2])
        | typ :: typs ->
            Exp.apply
              (Exp.ident (snarky_typ_path "*"))
              [fun_arg typ; (Nolabel, fold_tuple typs)]
        | _ -> failwith "Malformed tuple"
      in
      fold_tuple typs
  | _ ->
      Ppx_deriving.raise_errorf ~loc:typ.ptyp_loc
        "Cannot derive snarky for this type"

let str_of_type_decl ~options ~path type_decl =
  ignore options ;
  ignore path ;
  match type_decl.ptype_manifest with
  | Some typ ->
      Str.value Nonrecursive
        [ Vb.mk
            (Pat.var (Location.mknoloc "typ"))
            (exp_of_type ~options ~path typ) ]
  | None -> (
    match type_decl.ptype_kind with
    | Ptype_abstract ->
        Ppx_deriving.raise_errorf ~loc:type_decl.ptype_loc
          "Cannot generate a typ for an abstract type."
    | Ptype_record _ ->
        Ppx_deriving.raise_errorf ~loc:type_decl.ptype_loc
          "Cannot generate a typ for a record type."
    | Ptype_variant _ ->
        Ppx_deriving.raise_errorf ~loc:type_decl.ptype_loc
          "Cannot generate a typ for a variant type."
    | Ptype_open ->
        Ppx_deriving.raise_errorf ~loc:type_decl.ptype_loc
          "Cannot generate a typ for an open type." )

let () =
  Ppx_deriving.(
    register
      (create deriver
         ~type_decl_str:(fun ~options ~path type_decls ->
           List.map (str_of_type_decl ~options ~path) type_decls )
         ()))
