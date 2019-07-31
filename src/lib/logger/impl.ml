open Core
open Async

module Level = struct
  type t = Trace | Debug | Info | Warn | Error | Faulty_peer | Fatal
  [@@deriving sexp, compare, show {with_path= false}, enumerate]

  let of_string str =
    try Ok (t_of_sexp (Sexp.Atom str))
    with Sexp.Of_sexp_error (err, _) -> Error (Exn.to_string err)

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
    | `Assoc alist ->
        Ok (String.Map.of_alist_exn alist)
    | _ ->
        Error "expected object"

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
    | Ok ls ->
        ls
    | Error _ ->
        []

  let check_invariants t =
    let refs = metadata_references t.message in
    List.for_all refs ~f:(Metadata.mem t.metadata)
end

module Processor = struct
  module type S = sig
    type t

    val process : t -> Message.t -> string option
  end

  type t = T : (module S with type t = 't) * 't -> t

  module Raw = struct
    type t = unit

    let create () = ()

    let process () msg = Some (Yojson.Safe.to_string (Message.to_yojson msg))
  end

  module Pretty = struct
    type t = {log_level: Level.t; config: Logproc_lib.Interpolator.config}

    let create ~log_level ~config = {log_level; config}

    let process {log_level; config} msg =
      let open Message in
      if msg.level < log_level then None
      else
        match
          Logproc_lib.Interpolator.interpolate config msg.message msg.metadata
        with
        | Error err ->
            Core.printf "logproc interpolation error: %s\n" err ;
            None
        | Ok (str, extra) ->
            let formatted_extra =
              extra
              |> List.map ~f:(fun (k, v) -> "\n\t" ^ k ^ ": " ^ v)
              |> String.concat ~sep:""
            in
            let time =
              Core.Time.format msg.timestamp "%Y-%m-%d %H:%M:%S UTC"
                ~zone:Time.Zone.utc
            in
            Some
              ( time ^ " [" ^ Level.show msg.level ^ "] " ^ str
              ^ formatted_extra )
  end

  let raw () = T ((module Raw), Raw.create ())

  let pretty ~log_level ~config =
    T ((module Pretty), Pretty.create ~log_level ~config)
end

module Transport = struct
  module type S = sig
    type t

    val transport : t -> string -> unit
  end

  type t = T : (module S with type t = 't) * 't -> t

  module Stdout = struct
    type t = unit

    let create () = ()

    let transport () = Core.print_endline
  end

  let stdout () = T ((module Stdout), Stdout.create ())

  module File_system = struct
    module Dumb_logrotate = struct
      open Core.Unix

      let log_perm = 0o644

      let primary_log_name = "coda.log"

      let secondary_log_name = "coda.log.0"

      type t =
        { directory: string
        ; max_size: int
        ; mutable primary_log: File_descr.t
        ; mutable primary_log_size: int }

      let create ~directory ~max_size =
        if not (Result.is_ok (access directory [`Exists])) then
          mkdir_p ~perm:0o755 directory ;
        if not (Result.is_ok (access directory [`Exists; `Read; `Write])) then
          failwithf
            "cannot create log files: read/write permissions required on %s"
            directory () ;
        let primary_log_loc = Filename.concat directory primary_log_name in
        let primary_log_size, mode =
          if Result.is_ok (access primary_log_loc [`Exists; `Read; `Write])
          then
            let log_stats = stat primary_log_loc in
            (Int64.to_int_exn log_stats.st_size, [O_RDWR; O_APPEND])
          else (0, [O_RDWR; O_CREAT])
        in
        let primary_log = openfile ~perm:log_perm ~mode primary_log_loc in
        {directory; max_size; primary_log; primary_log_size}

      let rotate t =
        let primary_log_loc = Filename.concat t.directory primary_log_name in
        let secondary_log_loc =
          Filename.concat t.directory secondary_log_name
        in
        close t.primary_log ;
        rename ~src:primary_log_loc ~dst:secondary_log_loc ;
        t.primary_log
        <- openfile ~perm:log_perm ~mode:[O_RDWR; O_CREAT] primary_log_loc ;
        t.primary_log_size <- 0

      let transport t str =
        if t.primary_log_size > t.max_size then rotate t ;
        let str = str ^ "\n" in
        let len = String.length str in
        if write t.primary_log ~buf:(Bytes.of_string str) ~len <> len then
          printf "unexpected error writing to persistent log" ;
        t.primary_log_size <- t.primary_log_size + len
    end

    let dumb_logrotate ~directory ~max_size =
      T ((module Dumb_logrotate), Dumb_logrotate.create ~directory ~max_size)
  end
end

module Consumer_registry = struct
  type id = string

  type consumer = {processor: Processor.t; transport: Transport.t}

  type nonrec t = (id, consumer) List.Assoc.t ref

  let t : t = ref []

  let is_registered id = Option.is_some (List.Assoc.find !t id ~equal:( = ))

  let register ~id ~processor ~transport =
    if is_registered id then
      failwith "cannot register logger consumer with the same id twice"
    else t := List.Assoc.add !t id {processor; transport} ~equal:( = )

  let broadcast_log_message msg =
    (* TODO: warn or fail if there's no registered consumer? Issue #3000 *)
    List.iter !t ~f:(fun (_id, consumer) ->
        let (Processor.T ((module Processor_mod), processor)) =
          consumer.processor
        in
        let (Transport.T ((module Transport_mod), transport)) =
          consumer.transport
        in
        match Processor_mod.process processor msg with
        | Some str ->
            Transport_mod.transport transport str
        | None ->
            () )
end

type t = {null: bool; metadata: Metadata.t}

let create ?(metadata = []) ?(initialize_default_consumer = true) () =
  if initialize_default_consumer then
    if not (Consumer_registry.is_registered "default") then
      Consumer_registry.register ~id:"default" ~processor:(Processor.raw ())
        ~transport:(Transport.stdout ()) ;
  let pid = lazy (Unix.getpid () |> Pid.to_int) in
  let metadata' = ("pid", `Int (Lazy.force pid)) :: metadata in
  {null= false; metadata= Metadata.extend Metadata.empty metadata'}

let null () = {null= true; metadata= Metadata.empty}

let extend t metadata = {t with metadata= Metadata.extend t.metadata metadata}

let make_message (t : t) ~level ~module_ ~location ~metadata ~message =
  { Message.timestamp= Time.now ()
  ; level
  ; source= Source.create ~module_ ~location
  ; message
  ; metadata= Metadata.extend t.metadata metadata }

let log t ~level ~module_ ~location ?(metadata = []) fmt =
  let f message =
    if t.null then ()
    else
      let message =
        make_message t ~level ~module_ ~location ~metadata ~message
      in
      if Message.check_invariants message then
        Consumer_registry.broadcast_log_message message
      else failwith "invalid log call"
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

let faulty_peer_without_punishment = log ~level:Faulty_peer

(* deprecated, use Trust_system.record instead *)
let faulty_peer = faulty_peer_without_punishment
