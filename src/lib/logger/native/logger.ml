open Core_kernel

let max_log_line_length = 1 lsl 20

module Level = struct
  type t =
    | Internal
    | Spam
    | Trace
    | Debug
    | Info
    | Warn
    | Error
    | Faulty_peer
    | Fatal
  [@@deriving sexp, equal, compare, show { with_path = false }, enumerate]

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

  let pp ppf timestamp =
    (* This used to be
       [Core.Time.format timestamp "%Y-%m-%d %H:%M:%S UTC"
        ~zone:Time.Zone.utc]
       which uses the Unix string formatting under the hood, but we
       don't want to load that just for the pretty printing. Instead,
       we simulate it here.
    *)
    let zone = Time.Zone.utc in
    let date, time = Time.to_date_ofday ~zone timestamp in
    let time_parts = Time.Ofday.to_parts time in
    Format.fprintf ppf "%i-%02d-%02d %02d:%02d:%02d UTC" (Date.year date)
      (Date.month date |> Month.to_int)
      (Date.day date) time_parts.hr time_parts.min time_parts.sec

  let pretty_to_string timestamp = Format.asprintf "%a" pp timestamp

  let pretty_to_string_ref = ref pretty_to_string

  let set_pretty_to_string x = pretty_to_string_ref := x

  let pretty_to_string x = !pretty_to_string_ref x
end

module Source = struct
  type t = { module_ : string [@key "module"]; location : string }
  [@@deriving yojson]

  let create ~module_ ~location = { module_; location }
end

module Metadata = struct
  [%%versioned_binable
  module Stable = struct
    module V1 = struct
      type t = Yojson.Safe.t String.Map.t

      let to_latest = Fn.id

      let to_yojson t = `Assoc (String.Map.to_alist t)

      let of_yojson = function
        | `Assoc alist ->
            Ok (String.Map.of_alist_exn alist)
        | _ ->
            Error "Unexpected object"

      include
        Binable.Of_binable_without_uuid
          (Core_kernel.String.Stable.V1)
          (struct
            type nonrec t = t

            let to_binable t = to_yojson t |> Yojson.Safe.to_string

            let of_binable (t : string) : t =
              Yojson.Safe.from_string t |> of_yojson |> Result.ok
              |> Option.value_exn
          end)
    end
  end]

  [%%define_locally Stable.Latest.(to_yojson, of_yojson)]

  let empty = String.Map.empty

  let of_alist_exn = String.Map.of_alist_exn

  let mem = String.Map.mem

  let extend (t : t) alist =
    List.fold_left alist ~init:t ~f:(fun acc (key, data) ->
        String.Map.set acc ~key ~data )

  let merge (a : t) (b : t) = extend a (String.Map.to_alist b)
end

let global_metadata = ref []

(* List.append isn't tail-recursive (recurses over first arg), so hopefully it doesn't get too big! *)
let append_to_global_metadata l =
  global_metadata := List.append !global_metadata l

module Message = struct
  type t =
    { timestamp : Time.t
    ; level : Level.t
    ; source : Source.t option [@default None]
    ; message : string
    ; metadata : Metadata.t
    ; event_id : Structured_log_events.id option [@default None]
    }
  [@@deriving yojson]

  let check_invariants (t : t) =
    match Interpolator_lib.Interpolator.parse t.message with
    | Error _ ->
        false
    | Ok items ->
        List.for_all items ~f:(function
          | `Interpolate item ->
              Metadata.mem t.metadata item
          | `Raw _ ->
              true )
end

module Processor = struct
  module type S = sig
    type t

    val process : t -> Message.t -> string option
  end

  type t = T : (module S with type t = 't) * 't -> t

  let create m t = T (m, t)

  module Raw = struct
    type t = Level.t

    let create ~log_level = log_level

    let process log_level (msg : Message.t) =
      if Level.compare msg.level log_level < 0 then None
      else
        let msg_json_fields =
          Message.to_yojson msg |> Yojson.Safe.Util.to_assoc
        in
        let json =
          if Level.compare msg.level Level.Spam = 0 then
            `Assoc
              (List.filter msg_json_fields ~f:(fun (k, _) ->
                   not (String.equal k "source") ) )
          else `Assoc msg_json_fields
        in
        Some (Yojson.Safe.to_string json)
  end

  module Raw_structured_log_events = struct
    type t = Structured_log_events.Set.t

    let create (set : t) = set

    let process (set : t) (message : Message.t) : string option =
      let%bind.Option event_id = message.event_id in
      let%map.Option () = if Set.mem set event_id then Some () else None in
      Yojson.Safe.to_string (Message.to_yojson message)
  end

  module Pretty = struct
    type t =
      { log_level : Level.t; config : Interpolator_lib.Interpolator.config }

    let create ~log_level ~config = { log_level; config }

    let process { log_level; config } (msg : Message.t) =
      let open Message in
      if Level.compare msg.level log_level < 0 then None
      else
        match
          Interpolator_lib.Interpolator.interpolate config msg.message
            msg.metadata
        with
        | Error err ->
            Option.iter msg.source ~f:(fun source ->
                printf "logproc interpolation error in %s: %s\n" source.location
                  err ) ;
            None
        | Ok (str, extra) ->
            let msg =
              (* The previously existing \t has been changed to 2 spaces. *)
              Format.asprintf "@[<v 2>%a [%a] %s@,%a@]" Time.pp msg.timestamp
                Level.pp msg.level str
                (Format.pp_print_list ~pp_sep:Format.pp_print_cut
                   (fun ppf (k, v) -> Format.fprintf ppf "%s: %s" k v) )
                extra
            in
            Some msg
  end

  let raw ?(log_level = Level.Spam) () = T ((module Raw), Raw.create ~log_level)

  let raw_structured_log_events set =
    T ((module Raw_structured_log_events), Raw_structured_log_events.create set)

  let pretty ~log_level ~config =
    T ((module Pretty), Pretty.create ~log_level ~config)
end

module Transport = struct
  module type S = sig
    type t

    val transport : t -> string -> unit
  end

  type t = T : (module S with type t = 't) * 't -> t

  let create m t = T (m, t)

  module Stdout = struct
    type t = unit

    let create () = ()

    let transport () = print_endline
  end

  let stdout () = T ((module Stdout), Stdout.create ())

  module File_system = struct
    module Dumb_logrotate = struct
      open Core.Unix

      let log_perm = 0o644

      type t =
        { directory : string
        ; log_filename : string
        ; max_size : int
        ; num_rotate : int
        ; mutable curr_index : int
        ; mutable primary_log : File_descr.t
        ; mutable primary_log_size : int
        }

      let create ~directory ~max_size ~log_filename ~num_rotate =
        if not (Result.is_ok (access directory [ `Exists ])) then
          mkdir_p ~perm:0o755 directory ;
        if not (Result.is_ok (access directory [ `Exists; `Read; `Write ])) then
          failwithf
            "cannot create log files: read/write permissions required on %s"
            directory () ;
        let primary_log_loc = Filename.concat directory log_filename in
        let primary_log_size, mode =
          if Result.is_ok (access primary_log_loc [ `Exists; `Read; `Write ])
          then
            let log_stats = stat primary_log_loc in
            (Int64.to_int_exn log_stats.st_size, [ O_RDWR; O_APPEND ])
          else (0, [ O_RDWR; O_CREAT ])
        in
        let primary_log = openfile ~perm:log_perm ~mode primary_log_loc in
        { directory
        ; log_filename
        ; max_size
        ; primary_log
        ; primary_log_size
        ; num_rotate
        ; curr_index = 0
        }

      let rotate t =
        let primary_log_loc = Filename.concat t.directory t.log_filename in
        let secondary_log_filename =
          t.log_filename ^ "." ^ string_of_int t.curr_index
        in
        if t.curr_index < t.num_rotate then t.curr_index <- t.curr_index + 1
        else t.curr_index <- 0 ;
        let secondary_log_loc =
          Filename.concat t.directory secondary_log_filename
        in
        close t.primary_log ;
        rename ~src:primary_log_loc ~dst:secondary_log_loc ;
        t.primary_log <-
          openfile ~perm:log_perm ~mode:[ O_RDWR; O_CREAT ] primary_log_loc ;
        t.primary_log_size <- 0

      let transport t str =
        if t.primary_log_size > t.max_size then rotate t ;
        let str = str ^ "\n" in
        let len = String.length str in
        if write t.primary_log ~buf:(Bytes.of_string str) ~len <> len then
          printf "unexpected error writing to persistent log" ;
        t.primary_log_size <- t.primary_log_size + len
    end

    let dumb_logrotate ~directory ~log_filename ~max_size ~num_rotate =
      T
        ( (module Dumb_logrotate)
        , Dumb_logrotate.create ~directory ~log_filename ~max_size ~num_rotate
        )
  end

  module Raw = struct
    type t = string -> unit

    let create (f : t) = f

    let transport (f : t) str = f str
  end

  let raw f = T ((module Raw), Raw.create f)
end

module Consumer_registry = struct
  type consumer = { processor : Processor.t; transport : Transport.t }

  let default_consumer =
    lazy { processor = Processor.raw (); transport = Transport.stdout () }

  module Consumer_tbl = Hashtbl.Make (String)

  type t = consumer list Consumer_tbl.t

  let t : t = Consumer_tbl.create ()

  type id = string

  let register ~(id : id) ~processor ~transport =
    Consumer_tbl.add_multi t ~key:id ~data:{ processor; transport }

  let rec broadcast_log_message ~id msg =
    let consumers =
      match Hashtbl.find t id with
      | Some consumers ->
          consumers
      | None ->
          [ Lazy.force default_consumer ]
    in
    List.iter consumers ~f:(fun consumer ->
        let { processor = Processor.T ((module Processor), processor)
            ; transport = Transport.T ((module Transport), transport)
            } =
          consumer
        in
        match Processor.process processor msg with
        | Some str ->
            if
              String.equal id "oversized_logs"
              || String.length str < max_log_line_length
            then Transport.transport transport str
            else
              let max_log_line_error =
                { msg with
                  message =
                    "<log message elided as it exceeded the max log line \
                     length; see oversized logs for full log>"
                ; metadata = Metadata.empty
                }
              in
              Processor.process processor max_log_line_error
              |> Option.value
                   ~default:"failed to process max log line error message"
              |> Transport.transport transport ;
              broadcast_log_message ~id:"oversized_logs" msg
        | None ->
            () )
end

[%%versioned
module Stable = struct
  module V1 = struct
    type t = { null : bool; metadata : Metadata.Stable.V1.t; id : string }

    let to_latest = Fn.id
  end
end]

let metadata t = t.metadata

let create ?(metadata = []) ?(id = "default") () =
  { null = false; metadata = Metadata.extend Metadata.empty metadata; id }

let null () = { null = true; metadata = Metadata.empty; id = "default" }

let extend t metadata =
  { t with metadata = Metadata.extend t.metadata metadata }

let change_id { null; metadata; id = _ } ~id = { null; metadata; id }

let make_message (t : t) ~level ~module_ ~location ~metadata ~message ~event_id
    ~skip_merge_global_metadata =
  let global_metadata' =
    let m = !global_metadata in
    let key_cmp (k1, _) (k2, _) = String.compare k1 k2 in
    match List.find_all_dups m ~compare:key_cmp with
    | [] ->
        m
    | dups ->
        ("$duplicated_keys", `List (List.map ~f:(fun (s, _) -> `String s) dups))
        :: List.dedup_and_sort m ~compare:key_cmp
  in
  { Message.timestamp = Time.now ()
  ; level
  ; source = Some (Source.create ~module_ ~location)
  ; message
  ; metadata =
      ( if skip_merge_global_metadata then
        Metadata.extend Metadata.empty metadata
      else
        Metadata.extend
          (Metadata.merge (Metadata.of_alist_exn global_metadata') t.metadata)
          metadata )
  ; event_id
  }

let raw ({ id; _ } as t) msg =
  if t.null then ()
  else if Message.check_invariants msg then
    Consumer_registry.broadcast_log_message ~id msg
  else
    let msg' =
      Message.
        { timestamp = msg.timestamp
        ; level = Error
        ; source = None
        ; message =
            String.concat
              [ "invalid log call: "
              ; String.tr ~target:'$' ~replacement:'.' msg.message
              ]
        ; metadata = Metadata.empty
        ; event_id = None
        }
    in
    Consumer_registry.broadcast_log_message ~id msg'

let log t ~level ~module_ ~location ?(metadata = []) ?event_id fmt =
  let f message =
    let message' =
      make_message t ~level ~module_ ~location ~metadata ~message ~event_id
        ~skip_merge_global_metadata:(Level.equal level Level.Internal)
    in
    raw t message' ;
    match level with
    | Internal ->
        if Mina_compile_config.itn_features then
          let timestamp = message'.timestamp in
          let entries =
            Itn_logger.postprocess_message ~timestamp ~message ~metadata
          in
          List.iter entries ~f:(fun (timestamp, message, metadata) ->
              Itn_logger.log ~timestamp ~message ~metadata () )
    | _ ->
        ()
  in
  ksprintf f fmt

type 'a log_function =
     t
  -> module_:string
  -> location:string
  -> ?metadata:(string, Yojson.Safe.t) List.Assoc.t
  -> ?event_id:Structured_log_events.id
  -> ('a, unit, string, unit) format4
  -> 'a

let trace = log ~level:Trace

let internal = log ~level:Internal

let debug = log ~level:Debug

let info = log ~level:Info

let warn = log ~level:Warn

let error = log ~level:Error

let fatal = log ~level:Fatal

let faulty_peer_without_punishment = log ~level:Faulty_peer

let spam = log ~level:Spam ~module_:"" ~location:"" ?event_id:None

(* deprecated, use Trust_system.record instead *)
let faulty_peer = faulty_peer_without_punishment

module Structured = struct
  type log_function =
       t
    -> module_:string
    -> location:string
    -> ?metadata:(string, Yojson.Safe.t) List.Assoc.t
    -> Structured_log_events.t
    -> unit

  let log t ~level ~module_ ~location ?(metadata = []) event =
    let message, event_id, str_metadata = Structured_log_events.log event in
    let event_id = Some event_id in
    let metadata = str_metadata @ metadata in
    raw t
    @@ make_message t ~level ~module_ ~location ~metadata ~message ~event_id
         ~skip_merge_global_metadata:(Level.equal level Level.Internal)

  let trace = log ~level:Trace

  let debug = log ~level:Debug

  let info = log ~level:Info

  let warn = log ~level:Warn

  let error = log ~level:Error

  let fatal = log ~level:Fatal

  let faulty_peer_without_punishment = log ~level:Faulty_peer

  let best_tip_diff = log ~level:Spam ~module_:"" ~location:""
end

module Str = Structured

module Logger_id = struct
  let mina : Consumer_registry.id = "default"

  let best_tip_diff = "best_tip_diff"

  let rejected_blocks = "rejected_blocks"

  let snark_worker = "snark_worker"

  let oversized_logs = "oversized_logs"
end
