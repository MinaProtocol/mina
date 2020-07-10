open Core_kernel
open Ppxlib

let deriver = "register_event"

let digest s = Md5.digest_string s |> Md5.to_hex

let check_interpolations ~loc msg label_names =
  match Ast_convenience.get_str msg with
  | Some s -> (
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

let generate_loggers_and_parsers ~loc:_ ~path ty_ext msg_opt =
  let ctor, label_decls =
    match ty_ext.ptyext_constructors with
    (* record argument *)
    | [{pext_name; pext_kind= Pext_decl (Pcstr_record labels, None); _}] ->
        (pext_name.txt, labels)
    (* no arguments *)
    | [{pext_name; pext_kind= Pext_decl (Pcstr_tuple [], None); _}] ->
        (pext_name.txt, [])
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
    match msg_opt with
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
  let event_path = path ^ "." ^ ctor in
  let split_path = String.split path ~on:'.' in
  let to_yojson = Ppx_deriving_yojson.ser_expr_of_typ in
  let of_yojson = Ppx_deriving_yojson.desu_expr_of_typ in
  let elist ~f l = elist (List.map ~f l) in
  let plist ~f l = plist (List.map ~f l) in
  let record_pattern =
    let open Ast_helper.Pat in
    let arg =
      if has_record_arg then
        let fields =
          List.map label_names ~f:(fun label ->
              (Located.mk (Lident label), pvar label) )
        in
        Some (record fields Closed)
      else None
    in
    construct (Located.mk (Lident ctor)) arg
  in
  let record_expr =
    let open Ast_helper.Exp in
    let arg =
      if has_record_arg then
        let fields =
          List.map label_names ~f:(fun label ->
              (Located.mk (Lident label), evar label) )
        in
        Some (record fields None)
      else None
    in
    construct (Located.mk (Lident ctor)) arg
  in
  [ [%stri
      let ([%p pvar (event_name ^ "_structured_events_id")] :
            Structured_log_events.id) =
        Structured_log_events.id_of_string [%e estring (digest event_path)]]
  ; [%stri
      let ([%p pvar (event_name ^ "_structured_events_repr")] :
            Structured_log_events.repr) =
        { id= [%e evar (event_name ^ "_structured_events_id")]
        ; event_name= [%e estring event_path]
        ; arguments=
            Core_kernel.String.Set.of_list [%e elist ~f:estring label_names]
        ; log=
            (function
            | [%p record_pattern] ->
                Some
                  ( [%e msg]
                  , [%e
                      elist label_decls
                        ~f:(fun {pld_name= {txt= name; _}; pld_type; _} ->
                          [%expr
                            [%e estring name]
                            , [%e to_yojson pld_type] [%e evar name]] )] )
            | _ ->
                None )
        ; parse=
            (fun args ->
              let result =
                match args with
                | [%p
                    plist label_names ~f:(fun label ->
                        [%pat? [%p pstring label], [%p pvar label]] )] ->
                    [%e
                      List.fold_right label_decls
                        ~f:(fun {pld_name= {txt= name; _}; pld_type; _} acc ->
                          [%expr
                            Core_kernel.Result.bind
                              ([%e
                                 of_yojson
                                   ~path:(split_path @ [ctor; name])
                                   pld_type]
                                 [%e evar name])
                              ~f:(fun [%p pvar name] -> [%e acc])] )
                        ~init:
                          [%expr Core_kernel.Result.return [%e record_expr]]]
                | _ ->
                    failwith
                      [%e
                        estring
                          (sprintf "%s, parse: unexpected arguments" event_path)]
              in
              match result with Ok ev -> Some ev | Error _ -> None ) }]
  ; [%stri
      let () =
        Structured_log_events.register_constructor
          [%e evar (event_name ^ "_structured_events_repr")]] ]

let str_type_ext =
  let args =
    let open Ppxlib.Deriving.Args in
    empty +> arg "msg" __
  in
  Ppxlib.Deriving.Generator.make args generate_loggers_and_parsers

let () = Ppxlib.Deriving.add deriver ~str_type_ext |> Ppxlib.Deriving.ignore
