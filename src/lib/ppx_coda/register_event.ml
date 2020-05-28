open Core_kernel
open Ppxlib

let deriver = "register_event"

module Foo = Result

(* module in Structured_events library *)
let module_name = "Structured_events"

(* contains int_to_yojson, etc. *)
let yojson_prims_modl = "Yojson_prims"

let hash name =
  let open Digestif.SHA256 in
  let ctx0 = init () in
  let ctx1 = feed_string ctx0 name in
  get ctx1 |> to_raw_string

(* get variable names for `{to,of}_yojson` functions, based on the type

   the type must be an OCaml built-in, like `int` or `string`, or a type `t`
    in some module, like `Foo.t`

   missing: list or tuple types
*)
let make_yojson_name_of_core_type fname ty =
  let add_lib_qualifier s = String.concat ~sep:"." [yojson_prims_modl; s] in
  let fmt : ('a, Format.formatter, Base.unit, 'b) format4 =
    "Field type must be given by an OCaml type constructor or tuple"
  in
  match ty.ptyp_desc with
  | Ptyp_constr (lident, []) -> (
    match lident.txt with
    | Lident id ->
        add_lib_qualifier (id ^ "_" ^ fname)
    | Ldot (prefix, "t") ->
        String.concat ~sep:"." (Longident.flatten_exn prefix @ [fname])
    | _ ->
        Location.raise_errorf ~loc:ty.ptyp_loc fmt )
  | _ ->
      Location.raise_errorf ~loc:ty.ptyp_loc fmt

let to_yojson_of_core_type = make_yojson_name_of_core_type "to_yojson"

let of_yojson_of_core_type = make_yojson_name_of_core_type "of_yojson"

let core_kernel_result f = String.concat ["Core_kernel"; "Result"; f] ~sep:"."

let type_ext_str ~options ~path:_ (ty_ext : type_extension) =
  let add_module_qualifier s = String.concat ~sep:"." [module_name; s] in
  let ctor, record, label_decls =
    match ty_ext.ptyext_constructors with
    | [ { pext_name
        ; pext_kind= Pext_decl ((Pcstr_record labels as record), None)
        ; _ } ] ->
        (pext_name.txt, record, labels)
    | _ ->
        Location.raise_errorf ~loc:ty_ext.ptyext_path.loc
          "Constructor in type extension must take a single record argument"
  in
  let label_names =
    List.map label_decls ~f:(fun {pld_name= {txt; _}; _} -> txt)
  in
  let msg, msg_loc =
    match List.Assoc.find options "msg" ~equal:String.equal with
    | Some expr -> (
      match expr.pexp_desc with
      | Pexp_constant (Pconst_string (s, _)) ->
          (s, expr.pexp_loc)
      | _ ->
          Location.raise_errorf ~loc:expr.pexp_loc
            "The msg option must be a string constant" )
    | None ->
        let fields =
          List.map label_names ~f:(fun label -> sprintf "%s=$%s" label label)
        in
        (sprintf "%s {%s}" ctor (String.concat ~sep:"; " fields), Location.none)
  in
  (* check that every interpolation point $foo in msg has a matching label;
     OK to have extra labels not mentioned in message
  *)
  let len = String.length msg in
  let interpolates =
    let re = Str.regexp "\\$[a-z]\\([a-z]\\|[0-9]\\)*" in
    let rec loop start acc =
      if start >= len then acc
      else
        try
          let offs = Str.search_forward re msg start in
          let s = Str.matched_string msg in
          let s_len = String.length s in
          loop (offs + s_len) (String.sub s ~pos:1 ~len:(s_len - 1) :: acc)
        with _ ->
          (* wild-card match; actual match is deprecated Not_found *)
          acc
    in
    loop 0 []
  in
  List.iter interpolates ~f:(fun interp ->
      if not (List.mem label_names interp ~equal:String.equal) then
        Location.raise_errorf ~loc:msg_loc
          (Scanf.format_from_string
             (sprintf
                "The msg contains interpolation point \"$%s\" which is not a \
                 field in the record"
                interp)
             "") ) ;
  let event_name = String.lowercase ctor in
  let identifying = String.concat (event_name :: label_names) in
  let id_string = hash identifying in
  let (module Ast_builder) = Ast_builder.make ty_ext.ptyext_path.loc in
  let open Ast_builder in
  let core_type_of_string s =
    ptyp_constr {txt= Longident.parse s; loc= Location.none} []
  in
  let id_name = event_name ^ "_id" in
  let id_type = core_type_of_string (add_module_qualifier "id") in
  let id_of_string = add_module_qualifier "id_of_string" in
  let event_id =
    [%stri
      let ([%p pvar id_name] : [%t id_type]) =
        [%e evar id_of_string] [%e estring id_string]]
  in
  let repr_name = event_name ^ "_repr" in
  (* constructor declaration to build pattern *)
  let ctor_decl =
    { pcd_name= {txt= ctor; loc= Location.none}
    ; pcd_args= record
    ; pcd_res= None
    ; pcd_loc= Location.none
    ; pcd_attributes= [] }
  in
  let ctor_args =
    let ids =
      List.map label_names ~f:(fun label ->
          ({txt= Lident label; loc= Location.none}, pvar label) )
    in
    { ppat_desc= Ppat_record (ids, Closed)
    ; ppat_loc= Location.none
    ; ppat_attributes= [] }
  in
  let json_pairs =
    List.map label_decls ~f:(fun decl ->
        let name = estring decl.pld_name.txt in
        let var = evar decl.pld_name.txt in
        let to_json_var = evar (to_yojson_of_core_type decl.pld_type) in
        pexp_tuple [name; pexp_apply to_json_var [(Nolabel, var)]] )
  in
  let parse_args =
    List.map label_names ~f:(fun label -> ppat_tuple [pstring label; pvar label]
    )
  in
  let parse_args_pat =
    let empty_list =
      ppat_construct {txt= Lident "[]"; loc= Location.none} None
    in
    let cons = {txt= Lident "::"; loc= Location.none} in
    List.fold_right parse_args ~init:empty_list ~f:(fun hd tl ->
        ppat_construct cons (Some (ppat_tuple [hd; tl])) )
  in
  let equal_id = evar (add_module_qualifier "equal_id") in
  let repr_type = core_type_of_string (add_module_qualifier "repr") in
  let wrap_in_result_binds expr =
    let rec loop = function
      | [] ->
          eapply (evar (core_kernel_result "return")) [expr]
      | (decl : label_declaration) :: decls ->
          pexp_apply
            (evar (core_kernel_result "bind"))
            [ ( Nolabel
              , eapply
                  (evar (of_yojson_of_core_type decl.pld_type))
                  [evar decl.pld_name.txt] )
            ; ( Labelled "f"
              , pexp_fun Nolabel None (pvar decl.pld_name.txt) (loop decls) )
            ]
    in
    loop label_decls
  in
  let event_expr =
    let fields =
      List.map label_names ~f:(fun label ->
          ({txt= Lident label; loc= Location.none}, evar label) )
    in
    let record = pexp_record fields None in
    econstruct ctor_decl (Some record)
  in
  let binds = wrap_in_result_binds event_expr in
  let register_constructor = add_module_qualifier "register_constructor" in
  let repr =
    [%stri
      let ([%p pvar repr_name] : [%t repr_type]) =
        { log=
            (function
            | [%p pconstruct ctor_decl (Some ctor_args)] ->
                Some
                  ([%e estring msg], [%e evar id_name], [%e elist json_pairs])
            | _ ->
                None )
        ; parse=
            (fun id args ->
              if [%e equal_id] id [%e evar id_name] then
                let result =
                  match args with
                  | [%p parse_args_pat] ->
                      [%e binds]
                  | _ ->
                      failwith
                        (sprintf "%s, parse: unexpected arguments"
                           [%e estring ctor])
                in
                match result with Ok ev -> Some ev | Error _ -> None
              else None ) }]
  in
  let registration =
    [%stri
      let () =
        [%e evar register_constructor] [%e evar id_name] [%e evar repr_name]]
  in
  [event_id; repr; registration]

let () = Ppx_deriving.(register (create deriver ~type_ext_str ()))
