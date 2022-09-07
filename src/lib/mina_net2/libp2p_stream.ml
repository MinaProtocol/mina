open Core_kernel
open Async_kernel
open Network_peer

type participant = Us | Them [@@deriving equal, show]

let name_of_participant = function
  | Us ->
      "the local host"
  | Them ->
      "the remote host"

type state =
  | FullyOpen  (** Streams start in this state. Both sides can still write *)
  | HalfClosed of participant
      (** Streams move from [FullyOpen] to [HalfClosed `Us] when the write pipe is closed. Streams move from [FullyOpen] to [HalfClosed `Them] when [Stream.reset] is called or the remote host closes their write stream. *)
  | FullyClosed
      (** Streams move from [HalfClosed peer] to FullyClosed once the account_update that isn't peer has their "close write" event. Once a stream is FullyClosed, its resources are released. *)
[@@deriving equal, show]

type t =
  { protocol : string
  ; id : Libp2p_ipc.stream_id
  ; mutable state : state
  ; peer : Peer.t
  ; incoming_r : string Pipe.Reader.t
  ; incoming_w : string Pipe.Writer.t
  ; outgoing_w : string Pipe.Writer.t
  }

let id { id; _ } = id

let protocol { protocol; _ } = protocol

let remote_peer { peer; _ } = peer

let pipes { incoming_r; outgoing_w; _ } = (incoming_r, outgoing_w)

let data_received { incoming_w; _ } data =
  don't_wait_for (Pipe.write_if_open incoming_w data)

let reset ~helper { id; _ } =
  (* NOTE: do not close the pipes here. Reset_stream should end up
      notifying us that streamReadComplete. We can reset the stream (telling
      the remote peer to stop writing) and still be sending data ourselves. *)
  Libp2p_helper.do_rpc helper
    (module Libp2p_ipc.Rpcs.ResetStream)
    (Libp2p_ipc.Rpcs.ResetStream.create_request ~stream_id:id)
  |> Deferred.Or_error.ignore_m

let stream_state_invariant ~logger t =
  let us_closed = Pipe.is_closed t.outgoing_w in
  let them_closed = Pipe.is_closed t.incoming_w in
  [%log trace] "%sus_closed && %sthem_closed"
    (if us_closed then "" else "not ")
    (if them_closed then "" else "not ") ;
  match t.state with
  | FullyOpen ->
      (not us_closed) && not them_closed
  | HalfClosed Us ->
      us_closed && not them_closed
  | HalfClosed Them ->
      (not us_closed) && them_closed
  | FullyClosed ->
      us_closed && them_closed

(** Advance the stream_state automata, closing pipes as necessary. This
    executes atomically, using a bool + condition variable to synchronize
    updates. *)
let stream_closed ~logger ~who_closed t =
  (* FIXME: related to https://github.com/libp2p/go-libp2p-circuit/issues/18
         "preemptive" or half-closing a stream doesn't actually seem supported:
         after closing it we can't read anymore.
       NOTE: if we reintroduce this logic, it will make this function deferred,
         so we will need to also reintroduce a state lock here using
         `Async.Throttle.Sequencer.t`.
     let%map () =
       match who_closed with
       | Us ->
           match%map
             do_rpc net (module Rpcs.Close_stream) {stream_idx= stream.idx}
           with
           | Ok "closeStream success" ->
               ()
           | Ok v ->
               failwithf "helper broke RPC protocol: closeStream got %s" v
                 ()
           | Error e ->
               Error.raise e )
       | Them ->
           (* Helper notified us that the Go side closed its write pipe. *)
           Pipe.close t.incoming_w ;
           Deferred.unit
     in
  *)
  (* Helper notified us that the Go side closed its write pipe. *)
  if equal_participant who_closed Them then Pipe.close t.incoming_w ;
  let new_state =
    let log_double_close () =
      [%log error] "stream with index $index closed twice by $account_update"
        ~metadata:
          [ ("index", `String (Libp2p_ipc.stream_id_to_string t.id))
          ; ("account_update", `String (name_of_participant who_closed))
          ]
    in
    match t.state with
    | FullyOpen ->
        HalfClosed who_closed
    | HalfClosed previous_closer ->
        if equal_participant previous_closer who_closed then (
          log_double_close () ; HalfClosed previous_closer )
        else FullyClosed
    | FullyClosed ->
        log_double_close () ; FullyClosed
  in
  let old_state = t.state in
  t.state <- new_state ;
  (* TODO: maybe we can check some invariants on the Go side too? *)
  if not (stream_state_invariant ~logger t) then
    [%log error]
      "after $who_closed closed the stream, stream state invariant broke \
       (previous state: $old_stream_state)"
      ~metadata:
        [ ("who_closed", `String (name_of_participant who_closed))
        ; ("old_stream_state", `String (show_state old_state))
        ] ;
  `Stream_should_be_released (equal_state FullyOpen t.state)

let create_from_existing ~logger ~helper ~stream_id ~protocol ~peer
    ~release_stream =
  let incoming_r, incoming_w = Pipe.create () in
  let outgoing_r, outgoing_w = Pipe.create () in
  let t =
    { id = stream_id
    ; protocol
    ; state = FullyOpen
    ; peer
    ; incoming_r
    ; incoming_w
    ; outgoing_w
    }
  in
  let send_outgoing_messages_task =
    Pipe.iter outgoing_r ~f:(fun msg ->
        match%map
          Libp2p_helper.do_rpc helper
            (module Libp2p_ipc.Rpcs.SendStream)
            (Libp2p_ipc.Rpcs.SendStream.create_request ~stream_id ~data:msg)
        with
        | Ok _ ->
            ()
        | Error e ->
            [%log error] "error sending message on stream $idx: $error"
              ~metadata:
                [ ("idx", `String (Libp2p_ipc.stream_id_to_string stream_id))
                ; ("error", Error_json.error_to_yojson e)
                ] ;
            Pipe.close outgoing_w )
    (* TODO implement proper stream closing *)
    (* >>= ( fun () ->
       match%map Libp2p_helper.do_rpc helper
           (module Libp2p_ipc.Rpcs.CloseStream)
           (Libp2p_ipc.Rpcs.CloseStream.create_request ~stream_id) with
         | Ok _ ->
             ()
         | Error e ->
           [%log error] "error closing stream $idx: $error"
             ~metadata:
               [ ("idx", `String (Libp2p_ipc.stream_id_to_string stream_id))
               ; ("error", Error_json.error_to_yojson e)
               ] ;
             ) *)
  in
  upon send_outgoing_messages_task (fun () ->
      let (`Stream_should_be_released should_release) =
        stream_closed ~logger ~who_closed:Us t
      in
      if should_release then release_stream t.id ) ;
  t

(* TODO: should we really even be parsing the peer back from the client here?
   We will always have already had the full peer record by now... *)
let open_ ~logger ~helper ~protocol ~peer_id ~release_stream =
  let open Deferred.Or_error.Let_syntax in
  let%map response =
    Libp2p_helper.do_rpc helper
      (module Libp2p_ipc.Rpcs.OpenStream)
      (Libp2p_ipc.Rpcs.OpenStream.create_request ~peer_id ~protocol)
  in
  let open Libp2p_ipc.Reader.Libp2pHelperInterface.OpenStream.Response in
  let stream_id = stream_id_get response in
  let peer = Libp2p_ipc.unsafe_parse_peer (peer_get response) in
  create_from_existing ~logger ~helper ~stream_id ~protocol ~peer
    ~release_stream
