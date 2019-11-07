open Core
open Async
open Async_unix
open Deferred.Let_syntax
open Pipe_lib

exception Child_died

(* BTC alphabet *)
let alphabet =
  B58.make_alphabet
    "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

let of_b58_data = function
  | `String s -> (
    try Ok (Bytes.of_string s |> B58.decode alphabet |> Bytes.to_string)
    with B58.Invalid_base58_character ->
      Or_error.error_string "invalid base58" )
  | _ ->
      Or_error.error_string "expected a string"

let to_b58_data (s : string) =
  B58.encode alphabet (Bytes.of_string s) |> Bytes.to_string

let to_int_res x =
  match Yojson.Safe.Util.to_int_option x with
  | Some i ->
      Ok i
  | None ->
      Or_error.error_string "needed an int"

type keypair = {secret: string; public: string; peer_id: string}

type stream_state =
  | FullyOpen  (** Streams start in this state. Both sides can still write *)
  | HalfClosed of [`Us | `Them]
      (** Streams move from [FullyOpen] to [HalfClosed `Us] when the write pipe is closed. Streams move from [FullyOpen] to [HalfClosed `Them] when [Stream.reset] is called or the remote host closes their write stream. *)
  | FullyClosed
      (** Streams move from [HalfClosed peer] to FullyClosed once the party that isn't peer has their "close write" event. Once a stream is FullyClosed, its resources are released. *)

module Helper = struct
  type t =
    { subprocess: Process.t
    ; mutable failure_response: [`Die | `Ignore]
    ; lock_path: string
    ; conf_dir: string
    ; outstanding_requests: (int, Yojson.Safe.json Or_error.t Ivar.t) Hashtbl.t
          (**
      seqno is used to assign unique IDs to our outbound requests and index the
      tables below.

      The helper can also generate sequence numbers- but they are not the same space
      of sequence numbers!

      In general, if a message contains a seqno/idx, the response should contain the
      same seqno/idx.

      Some types would make it harder to misuse these integers.
    *)
    ; mutable seqno: int
    ; logger: Logger.t
    ; mutable me_keypair: keypair option
    ; subscriptions: (int, subscription) Hashtbl.t
    ; streams: (int, stream) Hashtbl.t
    ; protocol_handlers: (string, protocol_handler) Hashtbl.t
    ; mutable new_peer_callback: (string -> string list -> unit) option
    ; mutable finished: bool }

  and subscription =
    { net: t
    ; topic: string
    ; idx: int
    ; mutable closed: bool
    ; validator: string -> string -> bool Deferred.t
    ; write_pipe:
        ( string Envelope.Incoming.t
        , Strict_pipe.crash Strict_pipe.buffered
        , unit )
        Strict_pipe.Writer.t
    ; read_pipe: string Envelope.Incoming.t Strict_pipe.Reader.t }

  and stream =
    { net: t
    ; idx: int
    ; mutable state: stream_state
    ; protocol: string
    ; remote_peerid: string
    ; remote_addr: string
    ; incoming_r: string Pipe.Reader.t
    ; incoming_w: string Pipe.Writer.t
    ; outgoing_r: string Pipe.Reader.t
    ; outgoing_w: string Pipe.Writer.t }

  and protocol_handler =
    { net: t
    ; protocol_name: string
    ; mutable closed: bool
    ; on_handler_error: [`Raise | `Ignore | `Call of stream -> exn -> unit]
    ; f: stream -> unit Deferred.t }

  module type Rpc = sig
    type input [@@deriving to_yojson]

    type output [@@deriving of_yojson]

    val name : string
  end

  type ('a, 'b) rpc = (module Rpc with type input = 'a and type output = 'b)

  module Rpcs = struct
    module Send_stream_msg = struct
      type input = {stream_idx: int; data: string} [@@deriving yojson]

      type output = string [@@deriving yojson]

      let name = "sendStreamMsg"
    end

    module Close_stream = struct
      type input = {stream_idx: int} [@@deriving yojson]

      type output = string [@@deriving yojson]

      let name = "closeStream"
    end

    module Remove_stream_handler = struct
      type input = {protocol: string} [@@deriving yojson]

      type output = string [@@deriving yojson]

      let name = "removeStreamHandler"
    end

    module Generate_keypair = struct
      type input = unit

      let input_to_yojson () = `Assoc []

      type output = {sk: string; pk: string; peer_id: string}
      [@@deriving yojson]

      let name = "generateKeypair"
    end

    module Publish = struct
      type input = {topic: string; data: string} [@@deriving yojson]

      type output = string [@@deriving yojson]

      let name = "publish"
    end

    module Subscribe = struct
      type input = {topic: string; subscription_idx: int} [@@deriving yojson]

      type output = string [@@deriving yojson]

      let name = "subscribe"
    end

    module Unsubscribe = struct
      type input = {subscription_idx: int} [@@deriving yojson]

      type output = string [@@deriving yojson]

      let name = "unsubscribe"
    end

    module Configure = struct
      type input =
        { privk: string
        ; statedir: string
        ; ifaces: string list
        ; external_maddr: string
        ; network_id: string }
      [@@deriving yojson]

      type output = string [@@deriving yojson]

      let name = "configure"
    end

    module Listen = struct
      type input = {iface: string} [@@deriving yojson]

      type output = string list [@@deriving yojson]

      let name = "listen"
    end

    module Listening_addrs = struct
      type input = unit [@@deriving yojson]

      type output = string list [@@deriving yojson]

      let name = "listeningAddrs"
    end

    module Reset_stream = struct
      type input = {idx: int} [@@deriving yojson]

      type output = string [@@deriving yojson]

      let name = "resetStream"
    end

    module Add_stream_handler = struct
      type input = {protocol: string} [@@deriving yojson]

      type output = string [@@deriving yojson]

      let name = "addStreamHandler"
    end

    module Open_stream = struct
      type input = {peer: string; protocol: string} [@@deriving yojson]

      type output =
        {stream_idx: int; remote_addr: string; remote_peerid: string}
      [@@deriving yojson]

      let name = "openStream"
    end

    module Validation_complete = struct
      type input = {seqno: int; is_valid: bool} [@@deriving yojson]

      type output = string [@@deriving yojson]

      let name = "validationComplete"
    end

    module Add_peer = struct
      type input = {multiaddr: string} [@@deriving yojson]

      type output = string [@@deriving yojson]

      let name = "addPeer"
    end

    module Begin_advertising = struct
      type input = unit

      let input_to_yojson () = `Assoc []

      type output = string [@@deriving yojson]

      let name = "beginAdvertising"
    end
  end

  (** Generate the next sequence number for our side of the connection *)
  let genseq t =
    let v = t.seqno in
    t.seqno <- t.seqno + 1 ;
    v

  (** [do_rpc net rpc body] will encode [body] as JSON according to [rpc],
      send it to the helper, and return a deferred that resolves once the daemon
      gets around to replying. *)
  let do_rpc (type a b) t (rpc : (a, b) rpc) (body : a) : b Deferred.Or_error.t
      =
    let module M = (val rpc) in
    if not t.finished then (
      let res = Ivar.create () in
      let seqno = genseq t in
      Hashtbl.add_exn t.outstanding_requests ~key:seqno ~data:res ;
      let actual_obj =
        `Assoc
          [ ("seqno", `Int seqno)
          ; ("method", `String M.name)
          ; ("body", M.input_to_yojson body) ]
      in
      let rpc = Yojson.Safe.to_string actual_obj in
      Logger.trace t.logger "sending line to libp2p_helper: $line"
        ~module_:__MODULE__ ~location:__LOC__
        ~metadata:[("line", `String rpc)] ;
      Writer.write_line (Process.stdin t.subprocess) rpc ;
      let%map res_json = Ivar.read res in
      Or_error.bind res_json
        ~f:
          (Fn.compose (Result.map_error ~f:Error.of_string) M.output_of_yojson) )
    else Deferred.Or_error.error_string "helper process already exited"

  let stream_state_invariant stream =
    let us_closed = Pipe.is_closed stream.outgoing_w in
    let them_closed = Pipe.is_closed stream.incoming_w in
    match stream.state with
    | FullyOpen ->
        (not us_closed) && not them_closed
    | HalfClosed `Us ->
        us_closed && not them_closed
    | HalfClosed `Them ->
        (not us_closed) && them_closed
    | FullyClosed ->
        us_closed && them_closed

  (** Advance the stream_state automata, closing pipes as necessary. *)
  let advance_stream_state net (stream : stream) who_closed =
    let%map () =
      match who_closed with
      | `Us -> (
          match%map
            do_rpc net (module Rpcs.Close_stream) {stream_idx= stream.idx}
          with
          | Ok "closeStream success" ->
              ()
          | Ok v ->
              failwithf "helper broke RPC protocol: closeStream got %s" v ()
          | Error e ->
              Error.raise e )
      | `Them ->
          (* Helper notified us that the Go side closed its write pipe. *)
          Pipe.close stream.incoming_w ;
          Deferred.return ()
    in
    let double_close () =
      Logger.fatal net.logger ~module_:__MODULE__ ~location:__LOC__
        "stream with index $index closed twice by $party"
        ~metadata:
          [ ("index", `Int stream.idx)
          ; ( "party"
            , `String (match who_closed with `Us -> "us" | `Them -> "them") )
          ] ;
      failwith "stream double closed"
    in
    (* replace with [%derive.eq : [`Us|`Them]] when it is supported.*)
    let us_them_eq a b =
      match (a, b) with `Us, `Us | `Them, `Them -> true | _, _ -> false
    in
    let release () =
      match Hashtbl.find_and_remove net.streams stream.idx with
      | Some _ ->
          ()
      | None ->
          Logger.error net.logger
            "tried to release stream $idx but it was already gone"
            ~module_:__MODULE__ ~location:__LOC__
            ~metadata:[("idx", `Int stream.idx)]
    in
    stream.state
    <- ( match (stream.state, who_closed) with
       | FullyOpen, _ ->
           HalfClosed who_closed
       | HalfClosed other, _ ->
           if us_them_eq other who_closed then double_close () else release () ;
           FullyClosed
       | FullyClosed, _ ->
           double_close () ) ;
    (* TODO: maybe we can check some invariants on the Go side too? *)
    assert (stream_state_invariant stream)

  (** Track a new stream.

    This is used for both newly created outbound streams and incomming streams, and
    spawns the task that sends outbound messages to the helper.

    The writing end of the stream will be automatically be closed once the
    write pipe is closed.
  *)
  let make_stream net idx protocol remote_addr remote_peerid =
    let incoming_r, incoming_w = Pipe.create () in
    let outgoing_r, outgoing_w = Pipe.create () in
    let stream =
      { net
      ; idx
      ; state= FullyOpen
      ; remote_addr
      ; remote_peerid
      ; protocol
      ; incoming_r
      ; incoming_w
      ; outgoing_r
      ; outgoing_w }
    in
    (let%bind () =
       Pipe.iter outgoing_r ~f:(fun msg ->
           match%map
             do_rpc net
               (module Rpcs.Send_stream_msg)
               {stream_idx= idx; data= to_b58_data msg}
           with
           | Ok "sendStreamMsg success" ->
               ()
           | Ok v ->
               failwithf "helper broke RPC protocol: sendStreamMsg got %s" v ()
           | Error e ->
               Error.raise e )
     in
     advance_stream_state net stream `Us)
    |> don't_wait_for ;
    stream

  (** Parses a normal RPC response and resolves the deferred it answers. *)
  let handle_response t v =
    let open Yojson.Safe.Util in
    let open Or_error.Let_syntax in
    let%bind seq = v |> member "seqno" |> to_int_res in
    let err = v |> member "error" in
    let res = v |> member "success" in
    let fill_result =
      match (err, res) with
      | `Null, r ->
          Ok r
      | e, `Null ->
          Or_error.errorf "RPC #%d failed: %s" seq (Yojson.Safe.to_string e)
      | _, _ ->
          Or_error.errorf "unexpected response to RPC #%d: %s" seq
            (Yojson.Safe.to_string v)
    in
    match Hashtbl.find_and_remove t.outstanding_requests seq with
    | Some ivar ->
        Ivar.fill ivar fill_result ; Ok ()
    | None ->
        Or_error.errorf "spurious reply to RPC #%d: %s" seq
          (Yojson.Safe.to_string v)

  (** Parses an "upcall" and performs it.

    An upcall is like an RPC from the helper to us.*)

  module Upcall = struct
    module Data : sig
      type t = string [@@deriving yojson]
    end = struct
      type t = string

      let to_string t =
        B58.encode alphabet (Bytes.of_string t) |> Bytes.to_string

      let of_string s =
        Bytes.of_string s |> B58.decode alphabet |> Bytes.to_string

      let to_yojson s = `String (to_string s)

      let of_yojson = function
        | `String s -> (
          try Ok (of_string s)
          with exn -> Error Error.(to_string_hum (of_exn exn)) )
        | _ ->
            Error "expected a string"
    end

    module Publish = struct
      type t = {upcall: string; subscription_idx: int; data: Data.t}
      [@@deriving yojson]
    end

    module Validate = struct
      type t =
        { peer_id: string
        ; data: Data.t
        ; seqno: int
        ; upcall: string
        ; subscription_idx: int }
      [@@deriving yojson]
    end

    module Stream_lost = struct
      type t = {upcall: string; stream_idx: int; reason: string}
      [@@deriving yojson]
    end

    module Stream_read_complete = struct
      type t = {upcall: string; stream_idx: int} [@@deriving yojson]
    end

    module Incoming_stream_msg = struct
      type t = {upcall: string; stream_idx: int; data: Data.t}
      [@@deriving yojson]
    end

    module Incoming_stream = struct
      type t =
        { upcall: string
        ; remote_addr: string
        ; remote_peerid: string
        ; stream_idx: int
        ; protocol: string }
      [@@deriving yojson]
    end

    module Discovered_peer = struct
      type t = {upcall: string; peer_id: string; multiaddrs: string list}
      [@@deriving yojson]
    end

    let or_error (t : ('a, string) Result.t) =
      match t with
      | Ok a ->
          Ok a
      | Error s ->
          Or_error.errorf !"Error converting from json: %s" s
  end

  let handle_upcall t v =
    let open Yojson.Safe.Util in
    let open Or_error.Let_syntax in
    let open Upcall in
    match member "upcall" v |> to_string with
    (* Message published on one of our subscriptions *)
    | "publish" -> (
        let%bind m = Publish.of_yojson v |> or_error in
        let idx = m.subscription_idx in
        let data = m.data in
        match Hashtbl.find t.subscriptions idx with
        | Some sub ->
            if not sub.closed then
              (* TAKE CARE: doing anything with the return value here is UNSOUND
               because write_pipe has a cast type. We don't remember what the
               original 'return was. *)
              let _ =
                Strict_pipe.Writer.write sub.write_pipe
                  (Envelope.Incoming.wrap ~data ~sender:Envelope.Sender.Local)
              in
              ()
              (* TODO: add sender to Publish.t and include it here. *)
              (* TODO: think about exposing the PeerID of the originator as well? *)
            else
              Logger.warn t.logger
                "received msg for subscription $sub after unsubscribe, was it \
                 still in the stdout pipe?"
                ~module_:__MODULE__ ~location:__LOC__
                ~metadata:[("sub", `Int idx)] ;
            Ok ()
        | None ->
            Or_error.errorf
              "message published with inactive subsubscription %d" idx )
    (* Validate a message received on a subscription *)
    | "validate" -> (
        let%bind m = Validate.of_yojson v |> or_error in
        let idx = m.subscription_idx in
        let seqno = m.seqno in
        match Hashtbl.find t.subscriptions idx with
        | Some v ->
            (let open Deferred.Let_syntax in
            (let%bind is_valid = v.validator m.peer_id m.data in
             match%map
               do_rpc t (module Rpcs.Validation_complete) {seqno; is_valid}
             with
             | Ok "validationComplete success" ->
                 ()
             | Ok v ->
                 failwithf
                   "helper broke RPC protocol: validationComplete got %s" v ()
             | Error e ->
                 Logger.error t.logger
                   "error during validationComplete, ignoring and continuing: \
                    $error"
                   ~module_:__MODULE__ ~location:__LOC__
                   ~metadata:[("error", `String (Error.to_string_hum e))])
            |> don't_wait_for) ;
            Ok ()
        | None ->
            Or_error.errorf
              "asked to validate message for unregistered subscription idx %d"
              idx )
    (* A new inbound stream was opened *)
    | "incomingStream" -> (
        let%bind m = Incoming_stream.of_yojson v |> or_error in
        let stream_idx = m.stream_idx in
        let protocol = m.protocol in
        let stream =
          make_stream t stream_idx protocol m.remote_addr m.remote_peerid
        in
        match Hashtbl.find t.protocol_handlers protocol with
        | Some ph ->
            if not ph.closed then (
              Hashtbl.add_exn t.streams ~key:stream_idx ~data:stream ;
              don't_wait_for
                (let open Deferred.Let_syntax in
                (* Call the protocol handler. If it throws an exception,
                   handle it according to [on_handler_error]. Mimics
                  [Tcp.Server.create]. See [handle_protocol] doc comment.
                *)
                match%map
                  Monitor.try_with ~extract_exn:true (fun () -> ph.f stream)
                with
                | Ok () ->
                    ()
                | Error e -> (
                  try
                    match ph.on_handler_error with
                    | `Raise ->
                        raise e
                    | `Ignore ->
                        ()
                    | `Call f ->
                        f stream e
                  with handler_exn ->
                    ph.closed <- true ;
                    don't_wait_for
                      ( do_rpc t (module Rpcs.Remove_stream_handler) {protocol}
                      >>| fun _ -> Hashtbl.remove t.protocol_handlers protocol
                      ) ;
                    raise handler_exn )) ;
              Ok () )
            else
              (* silently ignore new streams for closed protocol handlers.
                 these are buffered stream open RPCs that were enqueued before
                 our close went into effect. *)
              (* TODO: we leak the new pipes here*)
              Ok ()
        | None ->
            (* TODO: punish *)
            Or_error.errorf "incoming stream for protocol we don't know about?"
        )
    | "discoveredPeer" ->
        let%map p = Discovered_peer.of_yojson v |> or_error in
        Option.iter t.new_peer_callback ~f:(fun cb -> cb p.peer_id p.multiaddrs)
    (* Received a message on some stream *)
    | "incomingStreamMsg" -> (
        let%bind m = Incoming_stream_msg.of_yojson v |> or_error in
        match Hashtbl.find t.streams m.stream_idx with
        | Some {incoming_w; _} ->
            don't_wait_for (Pipe.write incoming_w m.data) ;
            Ok ()
        | None ->
            Or_error.errorf
              "incoming stream message for stream we don't know about?" )
    (* Stream was reset, either by the remote peer or an error on our end. *)
    | "streamLost" ->
        let%bind m = Stream_lost.of_yojson v |> or_error in
        let stream_idx = m.stream_idx in
        Logger.warn t.logger
          "Encountered error while reading stream $idx: $error"
          ~module_:__MODULE__ ~location:__LOC__
          ~metadata:[("error", `String m.reason); ("idx", `Int stream_idx)] ;
        Ok ()
    (* The remote peer closed its write end of one of our streams *)
    | "streamReadComplete" -> (
        let%bind m = Stream_read_complete.of_yojson v |> or_error in
        let stream_idx = m.stream_idx in
        match Hashtbl.find t.streams stream_idx with
        | Some stream ->
            advance_stream_state t stream `Them |> don't_wait_for ;
            Ok ()
        | None ->
            Or_error.errorf
              "streamReadComplete for stream we don't know about %d" stream_idx
        )
    | s ->
        Or_error.errorf "unknown upcall %s" s

  let create logger subprocess conf_dir lock_path =
    let t =
      { subprocess
      ; failure_response= `Die
      ; lock_path
      ; conf_dir
      ; logger
      ; me_keypair= None
      ; outstanding_requests= Hashtbl.create (module Int)
      ; subscriptions= Hashtbl.create (module Int)
      ; streams= Hashtbl.create (module Int)
      ; new_peer_callback= None
      ; protocol_handlers= Hashtbl.create (module String)
      ; seqno= 1
      ; finished= false }
    in
    let err = Process.stderr subprocess in
    let errlines = Reader.lines err in
    let lines = Process.stdout subprocess |> Reader.lines in
    Pipe.iter errlines ~f:(fun line ->
        (* TODO: the log messages are JSON, parse them and log at the appropriate level *)
        Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
          "log message from libp2p_helper: $line"
          ~metadata:[("line", `String line)] ;
        Deferred.unit )
    |> don't_wait_for ;
    Pipe.iter lines ~f:(fun line ->
        let open Yojson.Safe.Util in
        let v = Yojson.Safe.from_string line in
        Logger.trace logger "handling line from helper: $line"
          ~module_:__MODULE__ ~location:__LOC__
          ~metadata:[("line", `String line)] ;
        ( match
            if member "upcall" v = `Null then handle_response t v
            else handle_upcall t v
          with
        | Ok () ->
            ()
        | Error e ->
            Logger.error logger "handling line from helper failed! $err"
              ~module_:__MODULE__ ~location:__LOC__
              ~metadata:
                [ ("line", `String line)
                ; ("err", `String (Error.to_string_hum e)) ] ) ;
        Deferred.unit )
    |> don't_wait_for ;
    t
end [@(* Warning 30 is about field labels being defined in multiple types.
     It means more disambiguation has to happen sometimes but it doesn't
     seem to be a big deal. *)
      warning
      "-30"]

type net = Helper.t

type peer_id = string

module Keypair = struct
  type t = keypair

  let random net =
    match%map Helper.do_rpc net (module Helper.Rpcs.Generate_keypair) () with
    | Ok {sk; pk; peer_id} ->
        (let open Or_error.Let_syntax in
        let%bind secret = of_b58_data (`String sk) in
        let%map public = of_b58_data (`String pk) in
        {secret; public; peer_id})
        |> Or_error.ok_exn
    | Error e ->
        failwithf "other RPC error generateKeypair: %s" (Error.to_string_hum e)
          ()

  let secret_key_base58 {secret; _} = to_b58_data secret

  let to_string {secret; public; peer_id} =
    String.concat ~sep:"," [to_b58_data secret; to_b58_data public; peer_id]

  let of_string s =
    let with_semicolon =
      match String.split s ~on:';' with
      | [secret_b58; public_b58; peer_id] ->
          let open Or_error.Let_syntax in
          let%map secret = of_b58_data (`String secret_b58)
          and public = of_b58_data (`String public_b58) in
          {secret; public; peer_id}
      | _ ->
          Or_error.errorf "%s is not a valid Keypair.to_string output" s
    in
    let with_comma =
      match String.split s ~on:',' with
      | [secret_b58; public_b58; peer_id] ->
          let open Or_error.Let_syntax in
          let%map secret = of_b58_data (`String secret_b58)
          and public = of_b58_data (`String public_b58) in
          {secret; public; peer_id}
      | _ ->
          Or_error.errorf "%s is not a valid Keypair.to_string output" s
    in
    if Or_error.is_error with_semicolon then with_comma else with_semicolon

  let to_peerid {peer_id; _} = peer_id
end

module PeerID = struct
  type t = peer_id

  let to_string t = t

  let of_keypair = Keypair.to_peerid
end

module Multiaddr = struct
  type t = string

  let to_string t = t

  let of_string t = t
end

type discovered_peer = {id: PeerID.t; maddrs: Multiaddr.t list}

module Pubsub = struct
  let publish net ~topic ~data =
    match%map
      Helper.do_rpc net
        (module Helper.Rpcs.Publish)
        {topic; data= to_b58_data data}
      |> Deferred.Or_error.ok_exn
    with
    | "publish success" ->
        ()
    | v ->
        failwithf "helper broke RPC protocol: publish got %s" v ()

  module Subscription = struct
    type t = Helper.subscription =
      { net: Helper.t
      ; topic: string
      ; idx: int
      ; mutable closed: bool
      ; validator: string -> string -> bool Deferred.t
      ; write_pipe:
          ( string Envelope.Incoming.t
          , Strict_pipe.crash Strict_pipe.buffered
          , unit )
          Strict_pipe.Writer.t
      ; read_pipe: string Envelope.Incoming.t Strict_pipe.Reader.t }

    let publish {net; topic; _} message = publish net ~topic ~data:message

    let unsubscribe ({net; idx; write_pipe; _} as t) =
      if not t.closed then (
        t.closed <- true ;
        Strict_pipe.Writer.close write_pipe ;
        match%map
          Helper.do_rpc net
            (module Helper.Rpcs.Unsubscribe)
            {subscription_idx= idx}
          |> Deferred.Or_error.ok_exn
        with
        | "unsubscribe success" ->
            Ok ()
        | v ->
            failwithf "helper broke RPC protocol: unsubscribe got %s" v () )
      else Deferred.Or_error.error_string "already unsubscribed"

    let message_pipe {read_pipe; _} = read_pipe
  end

  let subscribe (net : net) (topic : string) ~should_forward_message =
    let subscription_idx = Helper.genseq net in
    let read_pipe, write_pipe =
      Strict_pipe.create
        ~name:(sprintf "subscription to topic «%s»" topic)
        Strict_pipe.(Buffered (`Capacity 64, `Overflow Crash))
    in
    let sub =
      { Subscription.net
      ; topic
      ; idx= subscription_idx
      ; closed= false
      ; validator=
          (fun s d -> should_forward_message ~sender:(s :> PeerID.t) ~data:d)
      ; write_pipe
      ; read_pipe }
    in
    (* Linear scan over all subscriptions. Should generally be small, probably not a problem. *)
    let already_exists_error =
      Hashtbl.fold net.subscriptions ~init:None ~f:(fun ~key:_ ~data acc ->
          if Option.is_some acc then acc
          else if String.equal data.topic topic then (
            Strict_pipe.Writer.close write_pipe ;
            Some (Or_error.errorf "already subscribed to topic %s" topic) )
          else acc )
    in
    match already_exists_error with
    | Some err ->
        return err
    | None -> (
        let%bind _ =
          match
            Hashtbl.add net.subscriptions ~key:subscription_idx ~data:sub
          with
          | `Ok ->
              return (Ok ())
          | `Duplicate ->
              failwith
                "fresh genseq was already present in subscription table?"
        in
        match%map
          Helper.do_rpc net
            (module Helper.Rpcs.Subscribe)
            {topic; subscription_idx}
        with
        | Ok "subscribe success" ->
            Ok sub
        | Ok j ->
            Strict_pipe.Writer.close write_pipe ;
            failwithf "helper broke RPC protocol: subscribe got %s" j ()
        | Error e ->
            Strict_pipe.Writer.close write_pipe ;
            Error e )
end

let me (net : Helper.t) = net.me_keypair

let configure net ~me ~external_maddr ~maddrs ~network_id ~on_new_peer =
  match%map
    Helper.do_rpc net
      (module Helper.Rpcs.Configure)
      { privk= Keypair.secret_key_base58 me
      ; statedir= net.conf_dir
      ; ifaces= List.map ~f:Multiaddr.to_string maddrs
      ; external_maddr= Multiaddr.to_string external_maddr
      ; network_id }
  with
  | Ok "configure success" ->
      net.me_keypair <- Some me ;
      net.new_peer_callback
      <- Some
           (fun peer_id peer_addrs ->
             on_new_peer
               { id= (peer_id :> PeerID.t)
               ; maddrs= List.map ~f:Multiaddr.of_string peer_addrs } ) ;
      Ok ()
  | Ok j ->
      failwithf "helper broke RPC protocol: configure got %s" j ()
  | Error e ->
      Error e

(** TODO: needs a new helper RPC.
    What should the semantics be? Only peers we currently have open
    connections to? Anybody in the peerbook? Only those we're gossiping to?
    *)
let peers _ = failwith "Coda_net2.peers not yet implemented"

let listen_on net iface =
  match%map Helper.do_rpc net (module Helper.Rpcs.Listen) {iface} with
  | Ok maddrs ->
      Ok maddrs
  | Error e ->
      Error e

let listening_addrs net =
  match%map Helper.do_rpc net (module Helper.Rpcs.Listening_addrs) () with
  | Ok maddrs ->
      Ok maddrs
  | Error e ->
      Error e

(** TODO: graceful shutdown. Reset all our streams, sync the databases, then
shutdown. Replace kill invocation with an RPC. *)
let shutdown (net : net) =
  net.failure_response <- `Ignore ;
  let%bind _ =
    Process.run_exn ~prog:"kill"
      ~args:[Pid.to_string (Process.pid net.subprocess)]
      ()
  in
  let%bind _ = Process.wait net.subprocess in
  Sys.remove net.lock_path

module Stream = struct
  type t = Helper.stream

  let pipes ({incoming_r; outgoing_w; _} : t) = (incoming_r, outgoing_w)

  let reset ({net; idx; _} : t) =
    (* NOTE: do not close the pipes here. Reset_stream should end up
    notifying us that streamReadComplete. We can reset the stream (telling
    the remote peer to stop writing) and still be sending data ourselves. *)
    match%map Helper.do_rpc net (module Helper.Rpcs.Reset_stream) {idx} with
    | Ok "resetStream success" ->
        Ok ()
    | Ok v ->
        Or_error.errorf "helper broke RPC protocol: resetStream got %s" v
    | Error e ->
        Error e

  let remote_peerid ({remote_peerid; _} : t) = remote_peerid

  let remote_addr ({remote_addr; _} : t) = remote_addr
end

module Protocol_handler = struct
  type t = Helper.protocol_handler

  let handling_protocol ({protocol_name; _} : t) = protocol_name

  let is_closed ({closed; _} : t) = closed

  let close_connections (net : net) for_protocol =
    Hashtbl.filter_inplace net.streams ~f:(fun stream ->
        if stream.protocol <> for_protocol then true
        else (
          don't_wait_for
            (* TODO: this probably needs to be more thorough than a reset. Also force the write pipe closed? *)
            (let%map _ = Stream.reset stream in
             ()) ;
          false ) )

  let close ?(reset_existing_streams = false) ({net; protocol_name; _} : t) =
    Hashtbl.remove net.protocol_handlers protocol_name ;
    let close_connections =
      if reset_existing_streams then close_connections else fun _ _ -> ()
    in
    match%map
      Helper.do_rpc net
        (module Helper.Rpcs.Remove_stream_handler)
        {protocol= protocol_name}
      |> Deferred.Or_error.ok_exn
    with
    | "removeStreamHandler success" ->
        close_connections net protocol_name
    | v ->
        close_connections net protocol_name ;
        failwithf "helper broke RPC protocol: addStreamHandler got %s" v ()
end

let handle_protocol net ~on_handler_error ~protocol f =
  let ph : Protocol_handler.t =
    {net; closed= false; on_handler_error; f; protocol_name= protocol}
  in
  if Hashtbl.find net.protocol_handlers protocol |> Option.is_some then
    Deferred.Or_error.errorf "already handling protocol %s" protocol
  else
    match%map
      Helper.do_rpc net (module Helper.Rpcs.Add_stream_handler) {protocol}
      |> Deferred.Or_error.ok_exn
    with
    | "addStreamHandler success" ->
        Hashtbl.add_exn net.protocol_handlers ~key:protocol ~data:ph ;
        Ok ph
    | v ->
        failwithf "helper broke RPC protocol: addStreamHandler got %s" v ()

let open_stream net ~protocol peer =
  match%map
    Helper.(
      do_rpc net
        (module Rpcs.Open_stream)
        {peer= PeerID.to_string peer; protocol})
  with
  | Ok {stream_idx; remote_addr; remote_peerid} ->
      let stream =
        Helper.make_stream net stream_idx protocol remote_addr remote_peerid
      in
      Hashtbl.add_exn net.streams ~key:stream_idx ~data:stream ;
      Ok stream
  | Error e ->
      Error e

let add_peer net maddr =
  match%map
    Helper.(
      do_rpc net (module Rpcs.Add_peer) {multiaddr= Multiaddr.to_string maddr})
  with
  | Ok "addPeer success" ->
      Ok ()
  | Ok v ->
      failwithf "helper broke RPC protocol: addPeer got %s" v ()
  | Error e ->
      Error e

let begin_advertising net =
  match%map Helper.(do_rpc net (module Rpcs.Begin_advertising) ()) with
  | Ok "beginAdvertising success" ->
      Ok ()
  | Ok v ->
      failwithf "helper broke RPC protocol: beginAdvertising got %s" v ()
  | Error e ->
      Error e

(* Create and helpers for create *)

(* Unfortunately, `dune runtest` runs in a pwd deep inside the build
 * directory. This hack finds the project root by recursively looking for the
   dune-project file. *)
let get_project_root () =
  let open Filename in
  let rec go dir =
    if Core.Sys.file_exists_exn @@ dir ^/ "src/dune-project" then Some dir
    else if String.equal dir "/" then None
    else go @@ fst @@ split dir
  in
  go @@ realpath current_dir_name

let lock_file = "libp2p_helper.lock"

let write_lock_file lock_path pid =
  Async.Writer.save lock_path ~contents:(Pid.to_string pid)

let keep_trying :
    f:('a -> 'b Deferred.Or_error.t) -> 'a list -> 'b Deferred.Or_error.t =
 fun ~f xs ->
  let open Deferred.Let_syntax in
  let rec go e xs : 'b Deferred.Or_error.t =
    match xs with
    | [] ->
        return e
    | x :: xs -> (
        match%bind f x with
        | Ok r ->
            return (Ok r)
        | Error e ->
            go (Error e) xs )
  in
  go (Or_error.error_string "empty input") xs

let create ~logger ~conf_dir =
  let conf_dir = conf_dir ^/ "libp2p_helper" in
  let%bind () = Unix.mkdir ~p:() conf_dir in
  let lock_path = Filename.concat conf_dir lock_file in
  let run_p2p () =
    (* This is where nix dumps the go artifact *)
    let libp2p_helper_binary =
      "src/app/libp2p_helper/result/bin/libp2p_helper"
    in
    (* This is where you'd manually install libp2p *)
    let coda_libp2p_helper = "coda-libp2p_helper" in
    let open Deferred.Let_syntax in
    match%map
      keep_trying
        ( ( Unix.getenv "CODA_LIBP2P_HELPER_PATH"
          |> Option.value ~default:coda_libp2p_helper )
        ::
        ( match get_project_root () with
        | Some path ->
            [path ^/ libp2p_helper_binary]
        | None ->
            [] ) )
        ~f:(fun prog -> Process.create ~prog ~args:[] ())
      |> Deferred.Or_error.map ~f:(fun p ->
             Helper.create logger p conf_dir lock_path )
    with
    | Ok p ->
        (* If the libp2p_helper process dies, kill the parent daemon process. Fix
       * for #550 *)
        Deferred.upon (Process.wait p.subprocess) (fun code ->
            p.finished <- true ;
            match (p.failure_response, code) with
            | `Ignore, _ | _, Ok () ->
                Hashtbl.iter p.outstanding_requests ~f:(fun iv ->
                    Ivar.fill iv
                      (Or_error.error_string
                         "libp2p_helper process died before answering") )
            | `Die, (Error _ as e) ->
                Logger.fatal logger ~module_:__MODULE__ ~location:__LOC__
                  !"libp2p_helper process died: %s"
                  (Unix.Exit_or_signal.to_string_hum e) ;
                raise Child_died ) ;
        Ok p
    | Error e ->
        Or_error.error_string
          ( "Could not start libp2p_helper. If you are a dev, did you forget \
             to `make libp2p_helper` and set CODA_LIBP2P_HELPER_PATH? Try \
             CODA_LIBP2P_HELPER_PATH=$PWD/src/app/libp2p_helper/result/bin/libp2p_helper "
          ^ Error.to_string_hum e )
  in
  let kill_locked_process ~logger =
    (* TODO: is there something better than this PID file pattern to use? *)
    match%bind Sys.file_exists lock_path with
    | `Yes -> (
        let%bind p = (* FIXME: TOCTOU *) Reader.file_contents lock_path in
        match%bind Process.run ~prog:"kill" ~args:[p] () with
        | Ok _ ->
            Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
              "Killed dead libp2p_helper process %s" p ;
            let%bind () = Sys.remove lock_path in
            (* Let the process die and be reaped. *)
            let%map () = after (sec 5.) in
            Ok ()
        | Error _ ->
            let%map () = Sys.remove lock_path in
            Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
              "Process %s does not exist and will not be killed (removing \
               lock fle)"
              p ;
            Ok () )
    | _ ->
        return @@ Ok ()
  in
  let open Deferred.Or_error.Let_syntax in
  let%bind () = kill_locked_process ~logger in
  match%bind Sys.is_directory conf_dir |> Deferred.map ~f:Or_error.return with
  | `Yes ->
      let%bind t = run_p2p () in
      let%map () =
        write_lock_file lock_path (Process.pid t.subprocess)
        |> Deferred.map ~f:Or_error.return
      in
      t
  | _ ->
      Deferred.Or_error.errorf "Config directory (%s) must exist" conf_dir

let%test_module "coda network tests" =
  ( module struct
    let () = Backtrace.elide := false

    let () = Async.Scheduler.set_record_backtraces true

    let logger = Logger.create ()

    let testmsg =
      "This is a test. This is a test of the Outdoor Warning System. This is \
       only a test."

    let setup_two_nodes network_id =
      let%bind a_tmp = Unix.mkdtemp "p2p_helper_test_a" in
      let%bind b_tmp = Unix.mkdtemp "p2p_helper_test_b" in
      let%bind a =
        create
          ~logger:(Logger.extend logger [("name", `String "a")])
          ~conf_dir:a_tmp
        >>| Or_error.ok_exn
      in
      let%bind b =
        create
          ~logger:(Logger.extend logger [("name", `String "b")])
          ~conf_dir:b_tmp
        >>| Or_error.ok_exn
      in
      let%bind kp_a = Keypair.random a in
      let%bind kp_b = Keypair.random a in
      let maddrs = ["/ip4/127.0.0.1/tcp/0"] in
      let%bind () =
        configure a ~external_maddr:(List.hd_exn maddrs) ~me:kp_a ~maddrs
          ~network_id ~on_new_peer:Fn.ignore
        >>| Or_error.ok_exn
      and () =
        configure b ~external_maddr:(List.hd_exn maddrs) ~me:kp_b ~maddrs
          ~network_id ~on_new_peer:Fn.ignore
        >>| Or_error.ok_exn
      in
      let%bind a_advert = begin_advertising a
      and b_advert = begin_advertising b in
      Or_error.ok_exn a_advert ;
      Or_error.ok_exn b_advert ;
      (* Give the helpers time to announce and discover each other on localhost *)
      let%map () = after (Time.Span.of_sec 1.5) in
      let shutdown () =
        let%bind () = shutdown a in
        let%bind () = shutdown b in
        let%bind () = File_system.remove_dir a_tmp in
        File_system.remove_dir b_tmp
      in
      (a, b, shutdown)

    let%test_unit "stream" =
      let test_def =
        let open Deferred.Let_syntax in
        let%bind a, b, shutdown = setup_two_nodes "test_stream" in
        let a_peerid = Keypair.to_peerid (me a |> Option.value_exn) in
        let handler_finished = ref false in
        let%bind echo_handler =
          handle_protocol a ~on_handler_error:`Raise ~protocol:"echo"
            (fun stream ->
              let r, w = Stream.pipes stream in
              let%map () = Pipe.transfer r w ~f:Fn.id in
              Pipe.close w ;
              handler_finished := true )
          |> Deferred.Or_error.ok_exn
        in
        let%bind stream =
          open_stream b ~protocol:"echo" a_peerid >>| Or_error.ok_exn
        in
        let r, w = Stream.pipes stream in
        Pipe.write_without_pushback w testmsg ;
        Pipe.close w ;
        let%bind msg = Pipe.read_all r in
        let msg = Queue.to_list msg |> String.concat in
        assert (msg = testmsg) ;
        assert !handler_finished ;
        let%bind () = Protocol_handler.close echo_handler in
        shutdown ()
      in
      Async.Thread_safe.block_on_async_exn (fun () -> test_def)

    let unwrap_eof = function
      | `Eof ->
          failwith "unexpected EOF"
      | `Ok a ->
          Envelope.Incoming.data a

    let three_str_eq a b c = assert (String.equal a b && String.equal b c)

    let%test_unit "pubsub" =
      let test_def =
        let open Deferred.Let_syntax in
        let%bind a, b, shutdown = setup_two_nodes "test_pubsub" in
        let should_forward_message ~sender:_ ~data:_ = return true in
        (* Give the libp2p helpers time to see each other. *)
        let%bind a_sub =
          Pubsub.subscribe a "test" ~should_forward_message
          |> Deferred.Or_error.ok_exn
        in
        let%bind b_sub =
          Pubsub.subscribe b "test" ~should_forward_message
          |> Deferred.Or_error.ok_exn
        in
        let a_r = Pubsub.Subscription.message_pipe a_sub in
        let b_r = Pubsub.Subscription.message_pipe b_sub in
        (* Give the subscriptions time to propagate *)
        let%bind () = after (sec 0.5) in
        let%bind () = Pubsub.Subscription.publish a_sub "msg from a" in
        (* Give the publish time to propagate *)
        let%bind () = after (sec 0.5) in
        (* FIXME: a shouldn't be receiving its own messages? *)
        let%bind a_msg = Strict_pipe.Reader.read a_r in
        let%bind b_msg = Strict_pipe.Reader.read b_r in
        three_str_eq "msg from a" (unwrap_eof a_msg) (unwrap_eof b_msg) ;
        let%bind () = Pubsub.Subscription.publish b_sub "msg from b" in
        (* Give the publish time to propagate *)
        let%bind () = after (sec 0.5) in
        let%bind a_msg = Strict_pipe.Reader.read a_r in
        let%bind b_msg = Strict_pipe.Reader.read b_r in
        three_str_eq "msg from b" (unwrap_eof a_msg) (unwrap_eof b_msg) ;
        shutdown ()
      in
      Async.Thread_safe.block_on_async_exn (fun () -> test_def)
  end )
