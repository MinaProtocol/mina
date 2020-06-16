open Core_kernel
open Ppxlib

let deriver = "register_event"

(* module in Structured_log_events library *)
let module_name = "Structured_log_events"

let hash name =
  let open Digestif.SHA256 in
  let ctx0 = init () in
  let ctx1 = feed_string ctx0 name in
  get ctx1 |> to_raw_string

let check_interpolations ~loc msg label_names =
  match msg.pexp_desc with
  | Pexp_constant (Pconst_string (s, _)) -> (
    (* check that every interpolation point $foo in msg has a matching label;
       OK to have extra labels not mentioned in message
    *)
    match Logproc_lib.Interpolator.parse s with
    | Error err ->
        Location.raise_errorf ~loc
          "Encountered an error while parsing the msg: %s" err
    | Ok items ->
        List.iter items ~f:(function
          | `Interpolate interp
            when not (List.mem ~equal:String.equal label_names interp) ->
              Location.raise_errorf ~loc
                "The msg contains interpolation point \"$%s\" which is not a \
                 field in the record"
                interp
          | _ ->
              () ) )
  | _ ->
      ()

let type_ext_str ~options ~path (ty_ext : type_extension) =
  let add_module_qualifier s = String.concat ~sep:"." [module_name; s] in
  let ctor, ctor_args, label_decls =
    match ty_ext.ptyext_constructors with
    (* record argument *)
    | [ { pext_name
        ; pext_kind= Pext_decl ((Pcstr_record labels as record), None)
        ; _ } ] ->
        (pext_name.txt, record, labels)
    (* no arguments *)
    | [{pext_name; pext_kind= Pext_decl ((Pcstr_tuple [] as tuple), None); _}]
      ->
        (pext_name.txt, tuple, [])
    | _ ->
        Location.raise_errorf ~loc:ty_ext.ptyext_path.loc
          "Constructor in type extension must take a single record argument, \
           or no argument"
  in
  let label_names =
    List.map label_decls ~f:(fun {pld_name= {txt; _}; _} -> txt)
  in
  let has_record_arg = not @@ List.is_empty label_names in
  let deriver_loc =
    (* succeeds, because we're calling this deriver *)
    let find_deriver = function
      | { pstr_desc=
            Pstr_eval ({pexp_desc= Pexp_ident {txt= Lident id; loc}; _}, _)
        ; _ }
      | { pstr_desc=
            Pstr_eval
              ( { pexp_desc=
                    Pexp_apply
                      ({pexp_desc= Pexp_ident {txt= Lident id; loc}; _}, _)
                ; _ }
              , _ )
        ; _ }
        when String.equal id deriver ->
          Some loc
      | _ ->
          failwith
            (sprintf "Expected structure item in payload for %s" deriver)
    in
    List.find_map_exn ty_ext.ptyext_attributes ~f:(fun ({txt; _}, payload) ->
        if String.equal txt "deriving" then
          match payload with
          | PStr stris ->
              Some (List.find_map_exn stris ~f:find_deriver)
          | _ ->
              failwith (sprintf "Expected structure payload for %s" deriver)
        else None )
  in
  let (module Ast_builder) = Ast_builder.make deriver_loc in
  let open Ast_builder in
  let (msg : expression), msg_loc =
    match List.Assoc.find options "msg" ~equal:String.equal with
    | Some expr ->
        (expr, expr.pexp_loc)
    | None ->
        let s =
          if has_record_arg then
            let fields =
              List.map label_names ~f:(fun label ->
                  sprintf "%s=$%s" label label )
            in
            sprintf "%s {%s}" ctor (String.concat ~sep:"; " fields)
          else sprintf "%s" ctor
        in
        (estring s, Location.none)
  in
  check_interpolations ~loc:msg_loc msg label_names ;
  let event_name = String.lowercase ctor in
  let identifying = String.concat (path @ [event_name]) ~sep:"." in
  let id_string = hash identifying in
  let core_type_of_string s =
    ptyp_constr {txt= Longident.parse s; loc= Location.none} []
  in
  let id_name = event_name ^ "_structured_events_id" in
  let id_type = core_type_of_string (add_module_qualifier "id") in
  let id_of_string = add_module_qualifier "id_of_string" in
  let event_id =
    [%stri
      let ([%p pvar id_name] : [%t id_type]) =
        [%e evar id_of_string] [%e estring id_string]]
  in
  let repr_name = event_name ^ "_structured_events_repr" in
  (* constructor declaration to build pattern *)
  let ctor_decl =
    { pcd_name= {txt= ctor; loc= Location.none}
    ; pcd_args= ctor_args
    ; pcd_res= None
    ; pcd_loc= Location.none
    ; pcd_attributes= [] }
  in
  let json_pairs =
    List.map label_decls ~f:(fun decl ->
        let name = estring decl.pld_name.txt in
        let var = evar decl.pld_name.txt in
        let to_json_var = Ppx_deriving_yojson.ser_expr_of_typ decl.pld_type in
        pexp_tuple [name; eapply to_json_var [var]] )
  in
  let parse_args =
    List.map label_names ~f:(fun label -> ppat_tuple [pstring label; pvar label]
    )
  in
  let parse_args_pat =
    List.fold_right parse_args
      ~init:[%pat? []]
      ~f:(fun hd tl -> [%pat? [%p hd] :: [%p tl]])
  in
  let equal_id = evar (add_module_qualifier "equal_id") in
  let repr_type = core_type_of_string (add_module_qualifier "repr") in
  let wrap_in_result_binds expr =
    List.fold_right label_decls
      ~init:[%expr Result.return [%e expr]]
      ~f:(fun decl acc ->
        [%expr
          Result.bind
            ([%e
               Ppx_deriving_yojson.desu_expr_of_typ
                 ~path:(path @ [ctor; decl.pld_name.txt])
                 decl.pld_type]
               [%e evar decl.pld_name.txt])
            ~f:(fun [%p pvar decl.pld_name.txt] -> [%e acc])] )
  in
  let event_expr =
    if has_record_arg then
      let fields =
        List.map label_names ~f:(fun label ->
            ({txt= Lident label; loc= Location.none}, evar label) )
      in
      let record = pexp_record fields None in
      econstruct ctor_decl (Some record)
    else econstruct ctor_decl None
  in
  let binds = wrap_in_result_binds event_expr in
  let register_constructor = add_module_qualifier "register_constructor" in
  let args_pattern =
    if has_record_arg then
      let pat_args =
        let ids =
          List.map label_names ~f:(fun label ->
              ({txt= Lident label; loc= Location.none}, pvar label) )
        in
        { ppat_desc= Ppat_record (ids, Closed)
        ; ppat_loc= Location.none
        ; ppat_attributes= [] }
      in
      pconstruct ctor_decl (Some pat_args)
    else pconstruct ctor_decl None
  in
  let repr =
    [%stri
      let ([%p pvar repr_name] : [%t repr_type]) =
        { log=
            (function
            | [%p args_pattern] ->
                Some ([%e msg], [%e evar id_name], [%e elist json_pairs])
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
    [%stri let () = [%e evar register_constructor] [%e evar repr_name]]
  in
  [event_id; repr; registration]

let () = Ppx_deriving.(register (create deriver ~type_ext_str ()))
