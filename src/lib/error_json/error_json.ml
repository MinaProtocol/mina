open Base

let rec sexp_to_yojson (sexp : Sexp.t) : Yojson.Safe.t =
  match sexp with
  | Atom str ->
      `String str
  | List sexps ->
      `List (List.map ~f:sexp_to_yojson sexps)

let rec sexp_of_yojson (json : Yojson.Safe.t) : (Sexp.t, string) Result.t =
  match json with
  | `String str ->
      Ok (Sexp.Atom str)
  | `List jsons ->
      let rev_sexps =
        List.fold_until ~init:[] jsons ~finish:Result.return
          ~f:(fun sexps json ->
            match sexp_of_yojson json with
            | Ok sexp ->
                Continue (sexp :: sexps)
            | Error str ->
                Stop (Error str) )
      in
      Result.map ~f:(fun l -> Sexp.List (List.rev l)) rev_sexps
  | _ ->
      Error "Error_json.sexp_of_yojson: Expected a string or a list"

type info_data =
  | Sexp of Sexp.t
  | String of string
  | Exn of exn
  | Of_list of int option * int * Yojson.Safe.t

(* Used to encode sub-lists of infos *)

type info_tag =
  { tag : string; data : Sexp.t option; loc : Source_code_position.t option }

type 'a info_repr =
  { base : 'a; rev_tags : info_tag list; backtrace : string option }

let info_repr_to_yojson (info : info_data info_repr) : Yojson.Safe.t =
  let base_pairs =
    match info.base with
    | Sexp sexp ->
        [ ("sexp", sexp_to_yojson sexp) ]
    | String str ->
        [ ("string", `String str) ]
    | Exn exn ->
        [ ( "exn_name"
          , `String Stdlib.Obj.Extension_constructor.(name @@ of_val exn) )
        ; ("exn", sexp_to_yojson (Sexplib.Conv.sexp_of_exn exn))
        ]
    | Of_list (Some trunc_after, length, json) ->
        [ ("multiple", json)
        ; ("length", `Int length)
        ; ("truncated_after", `Int trunc_after)
        ]
    | Of_list (None, length, json) ->
        [ ("multiple", json); ("length", `Int length) ]
  in
  let tags =
    let tag_to_json { tag; data; loc } =
      let jsons =
        match loc with
        | None ->
            []
        | Some loc ->
            [ ("loc", `String (Source_code_position.to_string loc)) ]
      in
      let jsons =
        match data with
        | None ->
            jsons
        | Some data ->
            ("sexp", sexp_to_yojson data) :: jsons
      in
      `Assoc (("tag", `String tag) :: jsons)
    in
    match info.rev_tags with
    | [] ->
        []
    | _ :: _ ->
        [ ("tags", `List (List.rev_map ~f:tag_to_json info.rev_tags)) ]
  in
  let backtrace =
    match info.backtrace with
    | None ->
        []
    | Some backtrace ->
        (* Split backtrace at lines so that it prints nicely in errors *)
        [ ( "backtrace"
          , `List
              (List.map ~f:(fun s -> `String s) (String.split_lines backtrace))
          )
        ]
  in
  `Assoc (base_pairs @ tags @ backtrace)

(* NOTE: Could also add a [of_yojson] version for everything except [Exn]
   (which could be converted to [String]), but it's not clear that it would
   ever be useful.
*)

let rec info_internal_repr_to_yojson_aux (info : Info.Internal_repr.t)
    (acc : unit info_repr) : info_data info_repr =
  match info with
  | Could_not_construct sexp ->
      { acc with base = Sexp (List [ Atom "Could_not_construct"; sexp ]) }
  | Sexp sexp ->
      { acc with base = Sexp sexp }
  | String str ->
      { acc with base = String str }
  | Exn exn ->
      { acc with base = Exn exn }
  | Tag_sexp (tag, sexp, loc) ->
      { acc with
        base = Sexp sexp
      ; rev_tags = { tag; data = None; loc } :: acc.rev_tags
      }
  | Tag_t (tag, info) ->
      info_internal_repr_to_yojson_aux info
        { acc with rev_tags = { tag; data = None; loc = None } :: acc.rev_tags }
  | Tag_arg (tag, data, info) ->
      info_internal_repr_to_yojson_aux info
        { acc with
          rev_tags = { tag; data = Some data; loc = None } :: acc.rev_tags
        }
  | Of_list (trunc_after, infos) ->
      let rec rev_take i acc_len infos acc_infos =
        match (i, infos) with
        | _, [] ->
            (None, acc_len, acc_infos)
        | None, info :: infos ->
            let json_info = info_internal_repr_to_yojson info in
            rev_take i (acc_len + 1) infos (json_info :: acc_infos)
        | Some i, info :: infos ->
            if i > 0 then
              let json_info = info_internal_repr_to_yojson info in
              rev_take
                (Some (i - 1))
                (acc_len + 1) infos (json_info :: acc_infos)
            else (Some acc_len, acc_len + 1 + List.length infos, acc_infos)
      in
      let trunc_after, length, rev_json_infos =
        rev_take trunc_after 0 infos []
      in
      let json_infos = `List (List.rev rev_json_infos) in
      { acc with base = Of_list (trunc_after, length, json_infos) }
  | With_backtrace (info, backtrace) ->
      info_internal_repr_to_yojson_aux info
        { acc with backtrace = Some backtrace }

and info_internal_repr_to_yojson (info : Info.Internal_repr.t) : Yojson.Safe.t =
  info_internal_repr_to_yojson_aux info
    { base = (); rev_tags = []; backtrace = None }
  |> info_repr_to_yojson

let info_to_yojson (info : Info.t) : Yojson.Safe.t =
  info_internal_repr_to_yojson (Info.Internal_repr.of_info info)

let error_to_yojson (err : Error.t) : Yojson.Safe.t =
  match info_to_yojson (err :> Info.t) with
  | `Assoc assocs ->
      `Assoc (("commit_id", `String Mina_version.commit_id) :: assocs)
  | json ->
      `Assoc [ ("commit_id", `String Mina_version.commit_id); ("error", json) ]
