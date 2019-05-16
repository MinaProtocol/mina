open Core
open Async
open Async_unix
open Deferred.Let_syntax
open Pipe_lib

[@@@ocaml.warning "-27"]

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
  | j ->
      Or_error.error_string "expected a string"

let to_b58_data (s : string) =
  B58.encode alphabet (Bytes.of_string s) |> Bytes.to_string

let to_int_res x =
  match Yojson.Safe.Util.to_int_option x with
  | Some i ->
      Ok i
  | None ->
      Or_error.error_string "needed an int"

let to_string_res x =
  match Yojson.Safe.Util.to_string_option x with
  | Some i ->
      Ok i
  | None ->
      Or_error.error_string "needed a string"

module PeerID = struct
  type t = string

  let to_string t = t

  let of_string s = s
end

module Helper = struct
  (* duplicate record field names in same module *)
  type t =
    { subprocess: Process.t
    ; mutable failure_response: [`Die | `Ignore]
    ; lock_path: string
    ; outstanding_requests: (int, Yojson.Safe.json Or_error.t Ivar.t) Hashtbl.t
    ; seqno: int ref
    ; logger: Logger.t
    ; subscriptions:
        ( int
        , ( string Envelope.Incoming.t
          , Strict_pipe.crash Strict_pipe.buffered
          , unit )
          Strict_pipe.Writer.t
          * subscription )
        Hashtbl.t
    ; validators:
        (string, peerid:string -> data:string -> bool Deferred.t) Hashtbl.t
    ; streams: (int, stream) Hashtbl.t
    ; protocol_handlers: (string, protocol_handler) Hashtbl.t
    ; mutable finished: bool }

  and subscription =
    { net: t
    ; topic: string
    ; idx: int
    ; mutable closed: bool
    ; write_pipe:
        ( string Envelope.Incoming.t
        , Strict_pipe.crash Strict_pipe.buffered
        , unit )
        Strict_pipe.Writer.t }

  and stream =
    { net: t
    ; idx: int
    ; protocol: string
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

  let genseq t =
    let v = !(t.seqno) in
    incr t.seqno ; v

  let do_rpc t name body =
    if not t.finished then (
      let res = Ivar.create () in
      let seqno = genseq t in
      Hashtbl.add_exn t.outstanding_requests ~key:seqno ~data:res ;
      let actual_obj =
        `Assoc
          [ ("seqno", `Int seqno)
          ; ("method", `String name)
          ; ("body", `Assoc body) ]
      in
      let rpc = Yojson.Safe.to_string actual_obj in
      Logger.trace t.logger "sending line to libp2p_helper: $line"
        ~module_:__MODULE__ ~location:__LOC__
        ~metadata:[("line", `String rpc)] ;
      Writer.write_line (Process.stdin t.subprocess) rpc ;
      Ivar.read res )
    else Deferred.Or_error.error_string "helper process already exited"

  let make_stream net idx protocol =
    let incoming_r, incoming_w = Pipe.create () in
    let outgoing_r, outgoing_w = Pipe.create () in
    Pipe.iter outgoing_r ~f:(fun msg ->
        match%map
          do_rpc net "sendStreamMsg"
            [("stream_idx", `Int idx); ("data", `String (to_b58_data msg))]
        with
        | Ok (`String "sendStreamMsg success") ->
            ()
        | Ok v ->
            (* XXX nowhere for these to go. raise it? *)
            (*Or_error.errorf "helper broke RPC protocol: sendStreamMsg got %s"
          (Yojson.Safe.to_string v)*)
            ()
        | Error e ->
            () )
    |> don't_wait_for ;
    {net; idx; protocol; incoming_r; incoming_w; outgoing_r; outgoing_w}

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

  let handle_upcall t v =
    let open Yojson.Safe.Util in
    let open Or_error.Let_syntax in
    match member "upcall" v |> to_string with
    | "publish" -> (
        let%bind idx = v |> member "subscription_idx" |> to_int_res in
        let%bind data = v |> member "data" |> of_b58_data in
        match Hashtbl.find t.subscriptions idx with
        | Some (pipe, sub) ->
            if not sub.closed then
              (* TAKE CARE: doing anything with the return value here is UNSOUND
                 because write_pipe has a cast type. We don't remember what the
                 original 'return was. *)
              let _ =
                Strict_pipe.Writer.write sub.write_pipe
                  (Envelope.Incoming.wrap ~data ~sender:Envelope.Sender.Local)
              in
              () (* TODO: sender *)
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
    | "validate" -> (
        let%bind peerid = v |> member "peer_id" |> to_string_res in
        let%bind data = v |> member "data" |> of_b58_data in
        let%bind topic = v |> member "topic" |> to_string_res in
        let%bind seqno = v |> member "seqno" |> to_int_res in
        match Hashtbl.find t.validators topic with
        | Some v ->
            (let open Deferred.Let_syntax in
            let%map is_valid = v ~peerid ~data in
            Writer.write
              (Process.stdin t.subprocess)
              (Yojson.Safe.to_string
                 (`Assoc [("seqno", `Int seqno); ("is_valid", `Bool is_valid)])))
            |> don't_wait_for ;
            Ok ()
        | None ->
            Or_error.errorf
              "asked to validate message for topic we haven't registered a \
               validator for %s"
              topic )
    | "incomingStream" -> (
        let%bind peer = v |> member "remote_maddr" |> to_string_res in
        let%bind stream_idx = v |> member "stream_idx" |> to_int_res in
        let%bind protocol = v |> member "protocol" |> to_string_res in
        let stream = make_stream t stream_idx protocol in
        match Hashtbl.find t.protocol_handlers protocol with
        | Some ph ->
            if not ph.closed then (
              Hashtbl.add_exn t.streams ~key:stream_idx ~data:stream ;
              don't_wait_for
                (let open Deferred.Let_syntax in
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
                      ( do_rpc t "removeStreamHandler"
                          [("protocol", `String protocol)]
                      >>| fun _ -> Hashtbl.remove t.protocol_handlers protocol
                      ) ;
                    raise e )) ;
              Ok () )
            else
              (* silently ignore new streams for closed protocol handlers *)
              Ok ()
        | None ->
            Or_error.errorf "incoming stream for protocol we don't know about?"
        )
    | "incomingStreamMsg" -> (
        let%bind stream_idx = v |> member "stream_idx" |> to_int_res in
        let%bind data = v |> member "data" |> of_b58_data in
        match Hashtbl.find t.streams stream_idx with
        | Some {incoming_w; _} ->
            don't_wait_for (Pipe.write incoming_w data) ;
            Ok ()
        | None ->
            Or_error.errorf
              "incoming stream message for stream we don't know about?" )
    | "streamLost" ->
        let%bind stream_idx = v |> member "stream_idx" |> to_int_res in
        let%bind reason = v |> member "reason" |> to_string_res in
        let ret =
          if Hashtbl.mem t.streams stream_idx then Ok ()
          else
            Or_error.errorf "lost a stream we don't know about: %d" stream_idx
        in
        Hashtbl.remove t.streams stream_idx ;
        ret
    | "streamReadComplete" -> (
        let%bind stream_idx = v |> member "stream_idx" |> to_int_res in
        match Hashtbl.find t.streams stream_idx with
        | Some {incoming_w; _} ->
            Pipe.close incoming_w ; Ok ()
        | None ->
            Or_error.errorf
              "streamReadComplete for stream we don't know about %d" stream_idx
        )
    | s ->
        Or_error.errorf "unknown upcall %s" s

  let create logger subprocess lock_path =
    let open Deferred.Or_error.Let_syntax in
    let t =
      { subprocess
      ; failure_response= `Die
      ; lock_path
      ; logger
      ; outstanding_requests= Hashtbl.create (module Int)
      ; subscriptions= Hashtbl.create (module Int)
      ; validators= Hashtbl.create (module String)
      ; streams= Hashtbl.create (module Int)
      ; protocol_handlers= Hashtbl.create (module String)
      ; seqno= ref 1
      ; finished= false }
    in
    let err = Process.stderr subprocess in
    let errlines = Reader.lines err in
    let lines = Process.stdout subprocess |> Reader.lines in
    Pipe.iter errlines ~f:(fun line ->
        (* TODO: the log messages from go are structured, we should copy the log level *)
        Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
          "log message from libp2p_helper: $line"
          ~metadata:[("line", `String line)] ;
        Deferred.unit )
    |> don't_wait_for ;
    Pipe.iter lines ~f:(fun line ->
        let open Yojson.Safe.Util in
        let v = Yojson.Safe.from_string line in
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
end [@warning "-30"]

type net = Helper.t

type peer_id = string

(* We hardcode support for only Ed25519 keys so we can keygen without calling go *)
module Keypair = struct
  type t = {secret: string; public: string}

  let random net =
    match%map Helper.do_rpc net "generateKeypair" [] with
    | Ok (`Assoc [("privk", `String secret); ("pubk", `String public)]) ->
        let open Or_error.Let_syntax in
        let%bind secret = of_b58_data (`String secret) in
        let%map public = of_b58_data (`String public) in
        {secret; public}
    | Ok j ->
        Or_error.errorf "helper broke RPC protocol: generateKeypair got %s"
          (Yojson.Safe.to_string j)
    | Error e ->
        Error e

  let safe_secret {secret; _} = to_b58_data secret

  let to_string {secret; public} =
    String.concat ~sep:";" [to_b58_data secret; to_b58_data public]
end

module Multiaddr = struct
  type t = string

  let to_string t = t

  let of_string t = t
end

module Pubsub = struct
  let publish net ~topic ~data =
    match%map
      Helper.do_rpc net "publish"
        [("topic", `String topic); ("data", `String (to_b58_data data))]
    with
    | Ok (`String "publish success") ->
        Ok ()
    | Ok v ->
        Or_error.errorf "helper broke RPC protocol: publish got %s"
          (Yojson.Safe.to_string v)
    | Error e ->
        Error e

  module Subscription = struct
    type t = Helper.subscription =
      { net: Helper.t
      ; topic: string
      ; idx: int
      ; mutable closed: bool
      ; write_pipe:
          ( string Envelope.Incoming.t
          , Strict_pipe.crash Strict_pipe.buffered
          , unit )
          Strict_pipe.Writer.t }

    let publish {net; topic; idx= _; closed= _; write_pipe= _} message =
      publish net ~topic ~data:message

    let unsubscribe ({net; idx; write_pipe; closed= _; topic= _} as t) =
      if not t.closed then (
        t.closed <- true ;
        Strict_pipe.Writer.close write_pipe ;
        match%map
          Helper.do_rpc net "unsubscribe" [("subscription_idx", `Int idx)]
        with
        | Ok (`String "unsubscribe success") ->
            Ok ()
        | Ok v ->
            Or_error.errorf "helper broke RPC protocol: unsubscribe got %s"
              (Yojson.Safe.to_string v)
        | Error e ->
            Error e )
      else Deferred.Or_error.error_string "already unsubscribed"
  end

  let subscribe (type a) (net : net) (topic : string)
      (out_pipe :
        ( string Envelope.Incoming.t
        , a Strict_pipe.buffered
        , unit )
        Strict_pipe.Writer.t) =
    let sub_num = Helper.genseq net in
    let cast_pipe :
        ( string Envelope.Incoming.t
        , Strict_pipe.crash Strict_pipe.buffered
        , unit )
        Strict_pipe.Writer.t =
      Obj.magic out_pipe
    in
    let sub =
      { Subscription.net
      ; closed= false
      ; topic
      ; idx= sub_num
      ; write_pipe= cast_pipe }
    in
    Hashtbl.add_exn net.subscriptions ~key:sub_num ~data:(cast_pipe, sub) ;
    match%map
      Helper.do_rpc net "subscribe"
        [("topic", `String topic); ("subscription_idx", `Int sub_num)]
    with
    | Ok (`String "subscribe success") ->
        Ok sub
    | Ok v ->
        Or_error.errorf "helper broke RPC protocol: unsubscribe got %s"
          (Yojson.Safe.to_string v)
    | Error e ->
        Error e

  let register_validator (net : net) topic ~f =
    match Hashtbl.find net.validators topic with
    | Some _ ->
        Deferred.Or_error.error_string
          "already have a validator for that topic"
    | None -> (
        let idx = Helper.genseq net in
        Hashtbl.add_exn net.validators ~key:topic ~data:f ;
        match%map
          Helper.do_rpc net "registerValidator"
            [("topic", `String topic); ("idx", `Int idx)]
        with
        | Ok (`String "register validator success") ->
            Ok ()
        | Ok v ->
            Or_error.errorf
              "helper broke RPC protocol: registerValidator got %s"
              (Yojson.Safe.to_string v)
        | Error e ->
            Error e )
end

let configure net ~me ~maddrs ~statedir ~network_id =
  match%map
    Helper.do_rpc net "configure"
      [ ("privk", `String (Keypair.safe_secret me))
      ; ("statedir", `String statedir)
      ; ( "ifaces"
        , `List (List.map ~f:(fun s -> `String (Multiaddr.to_string s)) maddrs)
        )
      ; ("network_id", `String network_id) ]
  with
  | Ok (`String "configure success") ->
      Ok ()
  | Ok j ->
      Or_error.errorf "helper broke RPC protocol: configure got %s"
        (Yojson.Safe.to_string j)
  | Error e ->
      Error e

(** TODO: do we need this? *)
let peers net = Deferred.return []

(** TODO: do we need this? *)
let random_peers net count = Deferred.return []

let listen_on net ma =
  match%map
    Helper.do_rpc net "listen" [("iface", `String (Multiaddr.to_string ma))]
  with
  | Ok (`List maddrs) ->
      let lots =
        List.map
          ~f:(fun s -> Or_error.map ~f:Multiaddr.of_string (to_string_res s))
          maddrs
      in
      Or_error.combine_errors lots
  | Ok v ->
      Or_error.errorf "helper broke RPC protocol: listen got %s"
        (Yojson.Safe.to_string v)
  | Error e ->
      Error e

(** TODO: graceful shutdown *)
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
    match%map Helper.do_rpc net "resetStream" [("idx", `Int idx)] with
    | Ok (`String "resetStream success") ->
        Ok ()
    | Ok v ->
        Or_error.errorf "helper broke RPC protocol: resetStream got %s"
          (Yojson.Safe.to_string v)
    | Error e ->
        Error e
end

module Protocol_handler = struct
  type t = Helper.protocol_handler

  let handling_protocol ({protocol_name; _} : t) = protocol_name

  let is_closed ({closed; _} : t) = closed

  let close_connections (net : net) for_real for_protocol =
    if for_real then (
      Hashtbl.filter_inplace net.streams
        ~f:(fun ({protocol; idx; _} as stream) ->
          if protocol <> for_protocol then false
          else (
            Stream.reset stream >>| Fn.const () |> don't_wait_for ;
            true ) ) ;
      Deferred.return (Ok ()) )
    else Deferred.return (Ok ())

  let close ?(reset_existing_streams = false) ({net; protocol_name; _} : t) =
    Hashtbl.remove net.protocol_handlers protocol_name ;
    match%bind
      Helper.do_rpc net "removeStreamHandler"
        [("protocol", `String protocol_name)]
    with
    | Ok (`String "removeStreamHandler success") ->
        close_connections net reset_existing_streams protocol_name
    | Ok v ->
        let%bind _ =
          close_connections net reset_existing_streams protocol_name
        in
        Deferred.Or_error.errorf
          "helper broke RPC protocol: addStreamHandler got %s"
          (Yojson.Safe.to_string v)
    | Error e ->
        Deferred.return (Error e)
end

let handle_protocol net ~on_handler_error ~protocol f =
  let ph : Protocol_handler.t =
    {net; closed= false; on_handler_error; f; protocol_name= protocol}
  in
  match%map
    Helper.do_rpc net "addStreamHandler" [("protocol", `String protocol)]
  with
  | Ok (`String "addStreamHandler success") ->
      Hashtbl.add_exn net.protocol_handlers ~key:protocol ~data:ph ;
      Ok ph
  | Ok v ->
      Or_error.errorf "helper broke RPC protocol: addStreamHandler got %s"
        (Yojson.Safe.to_string v)
  | Error e ->
      Error e

let open_stream net ~protocol peer =
  match%map
    Helper.do_rpc net "openStream"
      [ ("peer", `String (PeerID.to_string peer))
      ; ("protocol", `String protocol) ]
  with
  | Ok (`Int stream_idx) ->
      let stream = Helper.make_stream net stream_idx protocol in
      Hashtbl.add_exn net.streams ~key:stream_idx ~data:stream ;
      Ok stream
  | Ok v ->
      Or_error.errorf "helper broke RPC protocol: openStream got %s"
        (Yojson.Safe.to_string v)
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
  let lock_path = Filename.concat conf_dir lock_file in
  let run_p2p () =
    (* This is where nix dumps the go artifact *)
    let libp2p_helper_binary =
      "src/app/libp2p_helper/result/bin/libp2p_helper"
    in
    (* This is where you'd manually install kademlia *)
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
      |> Deferred.Or_error.map ~f:(fun p -> Helper.create logger p lock_path)
    with
    | Ok p ->
        (* If the libp2p_helper process dies, kill the parent daemon process. Fix
        * for #550 *)
        Deferred.upon (Process.wait p.subprocess) (fun code ->
            p.finished <- true ;
            ( match (p.failure_response, code) with
            | `Ignore, _ | _, Ok () ->
                ()
            | `Die, (Error _ as e) ->
                Logger.fatal logger ~module_:__MODULE__ ~location:__LOC__
                  !"libp2p_helper process died: %s"
                  (Unix.Exit_or_signal.to_string_hum e) ;
                raise Child_died ) ;
            Hashtbl.iter p.outstanding_requests ~f:(fun iv ->
                Ivar.fill iv
                  (Or_error.error_string
                     "libp2p_helper process died before answering") ) ) ;
        Ok p
    | Error e ->
        Or_error.error_string
          ( "If you are a dev, did you forget to `make libp2p_helper` and set \
             CODA_LIBP2P_HELPER_PATH? Try \
             CODA_LIBP2P_HELPER_PATH=$PWD/src/app/libp2p_helper/result/bin/libp2p_helper "
          ^ Error.to_string_hum e )
  in
  let kill_locked_process ~logger =
    match%bind Sys.file_exists lock_path with
    | `Yes -> (
        let%bind p = Reader.file_contents lock_path in
        match%bind Process.run ~prog:"kill" ~args:[p] () with
        | Ok _ ->
            Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
              "Killing Dead libp2p_helper Process %s" p ;
            let%map () = Sys.remove lock_path in
            Ok ()
        | Error _ ->
            Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
              "Process %s does not exists and will not be killed" p ;
            return @@ Ok () )
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
      don't_wait_for
        (Pipe.iter_without_pushback
           (Reader.pipe (Process.stderr t.subprocess))
           ~f:(fun str ->
             Logger.error logger ~module_:__MODULE__ ~location:__LOC__ "%s" str
             )) ;
      t
  | _ ->
      Deferred.Or_error.errorf "Config directory (%s) must exist" conf_dir
