(* register_event.ml -- deriver for structured events *)

(* When declaring new structured events, add the deriver.

   The constructor for the type can be nullary, or have a record argument

   The registration can specify a `msg` for the event, which can be any
      string-valued expression, or omit it (in which case the `msg` is
      computed from the constructor and any argument)

   A `msg` may refer to a record label `f` in the record argument with
   the syntax `$f`. Such references are checked at compile-time. For a label
   of type `M.t`, the function `M.to_yojson` must exist.

   Examples:

     -- nullary constructor, no msg
     type Structured_log_events.t += Foo
      [@@deriving register_event]

     -- nullary constructor, with string constant msg
     type Structured_log_events.t += Bar
      [@@deriving register_event { msg = "got a Bar!" }]

     -- record, with computed msg
     type Structured_log_events.t += Quux
      [@@deriving register_event { msg = sprintf "compiled at: %0.02f" (Unix.gettimeofday ()) }]

     -- record, with msg referring to record labels
     type Structured_log_events.t += Baz of { n : int; s : string; p : M.t }
      [@@deriving register_event { msg = "n = $n, s = $s, and p = $p" } ]
*)

open Core_kernel
open Ppxlib

let deriver = "register_event"

let digest s = Md5.digest_string s |> Md5.to_hex

let checked_interpolations_statically ~loc msg label_names =
  match msg with
  | { pexp_desc = Pexp_constant (Pconst_string (s, _, _)); _ } -> (
      (* check that every interpolation point $foo in msg has a matching label;
         OK to have extra labels not mentioned in message
      *)
      match Interpolator_lib.Interpolator.parse s with
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
                () ) ;
          true )
  | _ ->
      false

let generate_loggers_and_parsers ~loc:_ ~path ty_ext msg_opt =
  let ctor, label_decls =
    match ty_ext.ptyext_constructors with
    (* record argument *)
    | [ { pext_name; pext_kind = Pext_decl (Pcstr_record labels, None); _ } ] ->
        (pext_name.txt, labels)
    (* no arguments *)
    | [ { pext_name; pext_kind = Pext_decl (Pcstr_tuple [], None); _ } ] ->
        (pext_name.txt, [])
    | _ ->
        Location.raise_errorf ~loc:ty_ext.ptyext_path.loc
          "Constructor in type extension must take a single record argument, \
           or no argument"
  in
  let label_names =
    List.map label_decls ~f:(fun { pld_name = { txt; _ }; _ } -> txt)
  in
  let has_record_arg = not @@ List.is_empty label_names in
  let deriver_loc =
    (* succeeds, because we're calling this deriver *)
    let find_deriver = function
      | { pstr_desc =
            Pstr_eval ({ pexp_desc = Pexp_ident { txt = Lident id; loc }; _ }, _)
        ; _
        }
      | { pstr_desc =
            Pstr_eval
              ( { pexp_desc =
                    Pexp_apply
                      ({ pexp_desc = Pexp_ident { txt = Lident id; loc }; _ }, _)
                ; _
                }
              , _ )
        ; _
        }
        when String.equal id deriver ->
          Some loc
      | _ ->
          failwith (sprintf "Expected structure item in payload for %s" deriver)
    in
    List.find_map_exn ty_ext.ptyext_attributes
      ~f:(fun { attr_name = { txt; _ }; attr_payload = payload; _ } ->
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
  let checked_interpolations =
    checked_interpolations_statically ~loc:msg_loc msg label_names
  in
  let event_name = String.lowercase ctor in
  let event_path = path ^ "." ^ ctor in
  let split_path = String.split path ~on:'.' in
  let to_yojson = Ppx_deriving_yojson.ser_expr_of_typ in
  let of_yojson = Ppx_deriving_yojson.desu_expr_of_typ in
  let elist ~f l = elist (List.map ~f l) in
  let record_pattern =
    let arg =
      if has_record_arg then
        let fields =
          List.map label_names ~f:(fun label ->
              (Located.mk (Lident label), pvar label) )
        in
        Some (ppat_record fields Closed)
      else None
    in
    ppat_construct (Located.mk (Lident ctor)) arg
  in
  let record_expr =
    let arg =
      if has_record_arg then
        let fields =
          List.map label_names ~f:(fun label ->
              (Located.mk (Lident label), evar label) )
        in
        Some (pexp_record fields None)
      else None
    in
    pexp_construct (Located.mk (Lident ctor)) arg
  in
  let stris =
    [ [%stri
        let ([%p pvar (event_name ^ "_structured_events_id")] :
              Structured_log_events.id ) =
          Structured_log_events.id_of_string [%e estring (digest event_path)]]
    ; [%stri
        let ([%p pvar (event_name ^ "_structured_events_repr")] :
              Structured_log_events.repr ) =
          { id = [%e evar (event_name ^ "_structured_events_id")]
          ; event_name = [%e estring event_path]
          ; arguments =
              Core_kernel.String.Set.of_list [%e elist ~f:estring label_names]
          ; log =
              (function
              | [%p record_pattern] ->
                  Some
                    ( [%e msg]
                    , [%e
                        elist label_decls
                          ~f:(fun { pld_name = { txt = name; _ }; pld_type; _ }
                             ->
                            Ppx_deriving_yojson.wrap_runtime
                            @@ [%expr
                                 [%e estring name]
                                 , [%e to_yojson pld_type] [%e evar name]] )] )
              | _ ->
                  None )
          ; parse =
              (fun args ->
                let result =
                  let args_list = Core_kernel.String.Map.of_alist_exn args in
                  (* We use this to avoid an unused value warning. *)
                  ignore args_list ;
                  [%e
                    List.fold_right label_decls
                      ~f:(fun { pld_name = { txt = name; _ }; pld_type; _ } acc ->
                        Ppx_deriving_yojson.wrap_runtime
                        @@ [%expr
                             let module Result = Core_kernel.Result in
                             match
                               Core_kernel.Map.find args_list [%e estring name]
                             with
                             | Some [%p pvar name] ->
                                 Result.bind
                                   ([%e
                                      of_yojson
                                        ~path:(split_path @ [ ctor; name ])
                                        pld_type]
                                      [%e evar name] )
                                   ~f:(fun [%p pvar name] -> [%e acc])
                             | None ->
                                 Result.fail
                                   [%e
                                     estring
                                       (sprintf "%s, parse: missing argument %s"
                                          event_path name )]] )
                      ~init:[%expr Core_kernel.Result.return [%e record_expr]]]
                in
                match result with Ok ev -> Some ev | Error _ -> None )
          }]
    ; [%stri
        let () =
          Structured_log_events.register_constructor
            [%e evar (event_name ^ "_structured_events_repr")]]
    ]
  in
  if checked_interpolations then stris
  else
    let msg_loc_str =
      (* same formatting as in Ppxlib.Location.print *)
      estring
        (sprintf "File \"%s\", line %d, characters %d-%d:"
           msg_loc.loc_start.pos_fname msg_loc.loc_start.pos_lnum
           (msg_loc.loc_start.pos_cnum - msg_loc.loc_start.pos_bol)
           (msg_loc.loc_end.pos_cnum - msg_loc.loc_start.pos_bol) )
    in
    [%stri
      let () =
        Structured_log_events.check_interpolations_exn ~msg_loc:[%e msg_loc_str]
          [%e msg]
          [%e elist ~f:estring label_names]]
    :: stris

let generate_signature_items ~loc ~path:_ ty_ext =
  List.concat_map ty_ext.ptyext_constructors ~f:(fun { pext_name; _ } ->
      let event_name = String.lowercase pext_name.txt in
      let (module Ast_builder) = Ast_builder.make loc in
      let open Ast_builder in
      [ psig_value
          (value_description
             ~name:(Located.mk (event_name ^ "_structured_events_id"))
             ~type_:[%type: Structured_log_events.id] ~prim:[] )
      ; psig_value
          (value_description
             ~name:(Located.mk (event_name ^ "_structured_events_repr"))
             ~type_:[%type: Structured_log_events.repr] ~prim:[] )
      ] )

let str_type_ext =
  let args =
    let open Ppxlib.Deriving.Args in
    empty +> arg "msg" __
  in
  Ppxlib.Deriving.Generator.make args generate_loggers_and_parsers

let sig_type_ext = Ppxlib.Deriving.Generator.make_noarg generate_signature_items

let () =
  Ppxlib.Deriving.add deriver ~str_type_ext ~sig_type_ext
  |> Ppxlib.Deriving.ignore
