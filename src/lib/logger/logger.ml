open Core
open Async

module Level = struct
  type t = Trace | Debug | Info | Warn | Error | Faulty_peer | Fatal
  [@@deriving sexp, compare, show {with_path= false}]

  let of_string str =
    try Ok (t_of_sexp (Sexp.Atom str)) with Sexp.Of_sexp_error (err, _) ->
      Error (Exn.to_string err)

  let to_yojson t = `String (show t)

  let of_yojson json = of_string @@ Yojson.Safe.Util.to_string json
end

(* Core modules extended with Yojson converters *)
module Time = struct
  include Time

  let to_yojson t = `String (Time.to_string_abs t ~zone:Zone.utc)

  let of_yojson json =
    json |> Yojson.Safe.Util.to_string |> fun s -> Ok (Time.of_string s)
end

module Source = struct
  type t = {module_: string [@key "module"]; location: string}
  [@@deriving yojson]

  let create ~module_ ~location = {module_; location}
end

module Metadata = struct
  type t = Yojson.Safe.json String.Map.t

  let empty = String.Map.empty

  let to_yojson t = `Assoc (String.Map.to_alist t)

  let of_yojson = function
    | `Assoc alist -> Ok (String.Map.of_alist_exn alist)
    | _ -> Error "expected object"

  let mem = String.Map.mem

  let extend (t : t) alist =
    List.fold_left alist ~init:t ~f:(fun acc (key, data) ->
        String.Map.add_exn acc ~key ~data )
end

module Message = struct
  type t =
    { timestamp: Time.t
    ; level: Level.t
    ; source: Source.t
    ; message: string
    ; metadata: Metadata.t }
  [@@deriving yojson]

  let escape_string str =
    String.to_list str
    |> List.bind ~f:(function '"' -> ['\\'; '"'] | c -> [c])
    |> String.of_char_list

  let to_yojson m = to_yojson {m with message= escape_string m.message}

  let metadata_interpolation_regex = Re2.create_exn {|\$(\[a-zA-Z_]+)|}

  let metadata_references str =
    match Re2.find_all ~sub:(`Index 1) metadata_interpolation_regex str with
    | Ok ls -> ls
    | Error _ -> []

  let check_invariants t =
    let refs = metadata_references t.message in
    List.for_all refs ~f:(Metadata.mem t.metadata)
end

type t = {null: bool; metadata: Metadata.t}

let create ?(metadata = []) () =
  let pid = lazy (Unix.getpid () |> Pid.to_int) in
  let metadata' = ("pid", `Int (Lazy.force pid)) :: metadata in
  {null= false; metadata= Metadata.extend Metadata.empty metadata'}

let null () = {null= true; metadata= Metadata.empty}

let extend t metadata = {t with metadata= Metadata.extend t.metadata metadata}

let log t ~level ~module_ ~location ?(metadata = []) fmt =
  let f message =
    let open Message in
    if t.null then ()
    else
      let message =
        { timestamp= Time.now ()
        ; level
        ; source= Source.create ~module_ ~location
        ; message
        ; metadata= Metadata.extend t.metadata metadata }
      in
      if Message.check_invariants message then
        Message.to_yojson message |> Yojson.Safe.to_string |> print_endline
      else (* TODO: handle gracefully *)
        failwith "invalid log call"
  in
  ksprintf f fmt

type 'a log_function =
     t
  -> module_:string
  -> location:string
  -> ?metadata:(string, Yojson.Safe.json) List.Assoc.t
  -> ('a, unit, string, unit) format4
  -> 'a

let trace = log ~level:Trace

let debug = log ~level:Debug

let info = log ~level:Info

let warn = log ~level:Warn

let error = log ~level:Error

let fatal = log ~level:Fatal

let faulty_peer = log ~level:Faulty_peer
