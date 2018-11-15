open! Stdune
open Import

module Version = struct
  module T = struct
    type t = int * int

    let compare (major_a, minor_a) (major_b, minor_b) =
      match Int.compare major_a major_b with
      | (Gt | Lt) as ne -> ne
      | Eq -> Int.compare minor_a minor_b
  end

  include T

  module Infix = Comparable.Operators(T)

  let to_string (a, b) = sprintf "%u.%u" a b

  let to_sexp t = Sexp.Atom (to_string t)

  let encode t = Dune_lang.Encoder.string (to_string t)

  let decode : t Dune_lang.Decoder.t =
    let open Dune_lang.Decoder in
    raw >>| function
    | Atom (loc, A s) -> begin
        try
          Scanf.sscanf s "%u.%u" (fun a b -> (a, b))
        with _ ->
          Errors.fail loc "Atom of the form NNN.NNN expected"
      end
    | sexp ->
      of_sexp_error (Dune_lang.Ast.loc sexp) "Atom expected"

  let can_read
        ~parser_version:(parser_major, parser_minor)
        ~data_version:(data_major, data_minor) =
    let open Int.Infix in
    parser_major = data_major && parser_minor >= data_minor
end

module Supported_versions = struct
  type t = int Int.Map.t

  let to_sexp (t : t) =
    let open Sexp.Encoder in
    (list (pair int int)) (Int.Map.to_list t)

  let make l : t =
    match
      List.map l ~f:(fun (major, minor) -> (major, minor))
      |> Int.Map.of_list
    with
    | Ok x -> x
    | Error _ ->
      Exn.code_error
        "Syntax.create"
        [ "versions", Sexp.Encoder.list Version.to_sexp l ]

  let greatest_supported_version t = Option.value_exn (Int.Map.max_binding t)

  let is_supported t (major, minor) =
    match Int.Map.find t major with
    | Some minor' -> minor' >= minor
    | None -> false

  let supported_ranges t =
    Int.Map.to_list t |> List.map ~f:(fun (major, minor) ->
      ((major, 0), (major, minor)))
end

type t =
  { name : string
  ; desc : string
  ; key  : Version.t Univ_map.Key.t
  ; supported_versions : Supported_versions.t
  }

module Error_msg = struct
  let since t ver ~what =
    Printf.sprintf "%s is only available since version %s of %s"
      what (Version.to_string ver) t.desc
end

module Error = struct
  let since loc t ver ~what =
    Errors.fail loc "%s" @@ Error_msg.since t ver ~what

  let renamed_in loc t ver ~what ~to_ =
    Errors.fail loc "%s was renamed to '%s' in the %s version of %s"
      what to_ (Version.to_string ver) t.desc

  let deleted_in loc t ?repl ver ~what =
    Errors.fail loc "%s was deleted in version %s of %s%s"
      what (Version.to_string ver) t.desc
      (match repl with
       | None -> ""
       | Some s -> ".\n" ^ s)
end


let create ~name ~desc supported_versions =
  { name
  ; desc
  ; key = Univ_map.Key.create ~name Version.to_sexp
  ; supported_versions = Supported_versions.make supported_versions
  }

let name t = t.name

let check_supported t (loc, ver) =
  if not (Supported_versions.is_supported t.supported_versions ver) then
    Errors.fail loc "Version %s of %s is not supported.\n\
                  Supported versions:\n\
                  %s"
      (Version.to_string ver) t.name
      (String.concat ~sep:"\n"
         (List.map (Supported_versions.supported_ranges t.supported_versions)
            ~f:(fun (a, b) ->
              let open Version.Infix in
              if a = b then
                sprintf "- %s" (Version.to_string a)
              else
                sprintf "- %s to %s"
                  (Version.to_string a)
                  (Version.to_string b))))

let greatest_supported_version t =
  Supported_versions.greatest_supported_version t.supported_versions

let key t = t.key

open Dune_lang.Decoder

let set t ver parser =
  set t.key ver parser

let get_exn t =
  get t.key >>= function
  | Some x -> return x
  | None ->
    get_all >>| fun context ->
    Exn.code_error "Syntax identifier is unset"
      [ "name", Sexp.Encoder.string t.name
      ; "supported_versions", Supported_versions.to_sexp t.supported_versions
      ; "context", Univ_map.to_sexp context
      ]

let desc () =
  kind >>| fun kind ->
  match kind with
  | Values (loc, None) -> (loc, "This syntax")
  | Fields (loc, None) -> (loc, "This field")
  | Values (loc, Some s) -> (loc, sprintf "'%s'" s)
  | Fields (loc, Some s) -> (loc, sprintf "Field '%s'" s)

let deleted_in t ver =
  let open Version.Infix in
  get_exn t >>= fun current_ver ->
  if current_ver < ver then
    return ()
  else begin
    desc () >>= fun (loc, what) ->
    Error.deleted_in loc t ver ~what
  end

let renamed_in t ver ~to_ =
  let open Version.Infix in
  get_exn t >>= fun current_ver ->
  if current_ver < ver then
    return ()
  else begin
    desc () >>= fun (loc, what) ->
    Error.renamed_in loc t ver ~what ~to_
  end

let since ?(fatal=true) t ver =
  let open Version.Infix in
  get_exn t >>= fun current_ver ->
  if current_ver >= ver then
    return ()
  else
    desc () >>= function
    | (loc, what) when fatal -> Error.since loc t ver ~what
    | (loc, what) ->
      Errors.warn loc "%s" @@ Error_msg.since t ver ~what;
      return ()
