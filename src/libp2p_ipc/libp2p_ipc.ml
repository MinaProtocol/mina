open Async
open Core
open Stdint
open Pipe_lib
open Network_peer

(* TODO: convert most of these return values from builders to readers *)

include Ipc
module Rpcs = Rpcs
module Build = Build
open Build

exception Received_undefined_union of string * int

module Make_capnp_unique_id (Capnp_id : sig
  type t

  val of_uint64 : Uint64.t -> t

  val to_uint64 : t -> Uint64.t
end)
() =
struct
  module Uid = Unique_id.Int63 ()

  let of_int63 n = n |> Int63.to_int64 |> Uint64.of_int64 |> Capnp_id.of_uint64

  let to_int63 capnp_id =
    capnp_id |> Capnp_id.to_uint64 |> Uint64.to_int64 |> Int63.of_int64_exn

  let of_uid (uid : Uid.t) = of_int63 (uid :> Int63.t)

  module T = struct
    type t = Capnp_id.t

    let sexp_of_t = Fn.compose Int63.sexp_of_t to_int63

    let t_of_sexp = Fn.compose of_int63 Int63.t_of_sexp

    let hash = Fn.compose Int63.hash to_int63

    let hash_fold_t state id = id |> to_int63 |> Int63.hash_fold_t state

    let compare a b = Int63.compare (to_int63 a) (to_int63 b)
  end

  include T
  include Comparable.Make (T)
  include Hashable.Make (T)

  let to_string = Fn.compose Uint64.to_string Capnp_id.to_uint64

  let create () = of_uid (Uid.create ())
end

module Sequence_number =
  Make_capnp_unique_id
    (struct
      type t = sequence_number

      let of_uint64 n =
        build
          (module Builder.SequenceNumber)
          (op Builder.SequenceNumber.seqno_set n)

      let to_uint64 = Reader.SequenceNumber.seqno_get
    end)
    ()

module Subscription_id =
  Make_capnp_unique_id
    (struct
      type t = subscription_id

      let of_uint64 n =
        build
          (module Builder.SubscriptionId)
          (op Builder.SubscriptionId.id_set n)

      let to_uint64 = Reader.SubscriptionId.id_get
    end)
    ()

let undefined_union ~context n = raise (Received_undefined_union (context, n))

let () =
  Stdlib.Printexc.register_printer (function
    | Received_undefined_union (ctx, n) ->
        Some
          (Printf.sprintf
             "Received an undefined union for %s over the libp2p IPC: %n " ctx
             n)
    | _ ->
        None)

let compression = `None

let now () =
  let now_int64 =
    (* can we make this int time? worried about float truncation *)
    Time_ns.now () |> Time_ns.to_span_since_epoch |> Time_ns.Span.to_ns
    |> Int64.of_float
  in
  build (module Builder.UnixNano) Builder.UnixNano.(op nano_sec_set now_int64)

let unsafe_parse_peer_id peer_id =
  peer_id |> Reader.PeerId.id_get |> Peer.Id.unsafe_of_string

let unsafe_parse_peer peer_info =
  let open Reader.PeerInfo in
  let libp2p_port = libp2p_port_get peer_info in
  let host = Unix.Inet_addr.of_string (host_get peer_info) in
  let peer_id = unsafe_parse_peer_id (peer_id_get peer_info) in
  Peer.create host ~libp2p_port ~peer_id

let stream_id_to_string = Fn.compose Uint64.to_string Reader.StreamId.id_get

let multiaddr_to_string = Reader.Multiaddr.representation_get

let unix_nano_to_time_span unix_nano =
  unix_nano |> Reader.UnixNano.nano_sec_get |> Float.of_int64
  |> Time_ns.Span.of_ns |> Time_ns.of_span_since_epoch

let create_multiaddr representation =
  build'
    (module Builder.Multiaddr)
    (op Builder.Multiaddr.representation_set representation)

let create_peer_id peer_id =
  build' (module Builder.PeerId) (op Builder.PeerId.id_set peer_id)

let create_libp2p_config ~private_key ~statedir ~listen_on ?metrics_port
    ~external_multiaddr ~network_id ~unsafe_no_trust_ip ~flood ~direct_peers
    ~seed_peers ~peer_exchange ~mina_peer_exchange ~max_connections
    ~validation_queue_size ~gating_config =
  build
    (module Builder.Libp2pConfig)
    Builder.Libp2pConfig.(
      op private_key_set private_key
      *> op statedir_set statedir
      *> list_op listen_on_set_list listen_on
      *> optional op metrics_port_set_exn metrics_port
      *> builder_op external_multiaddr_set_builder external_multiaddr
      *> op network_id_set network_id
      *> op unsafe_no_trust_ip_set unsafe_no_trust_ip
      *> op flood_set flood
      *> list_op direct_peers_set_list direct_peers
      *> list_op seed_peers_set_list seed_peers
      *> op peer_exchange_set peer_exchange
      *> op mina_peer_exchange_set mina_peer_exchange
      *> op max_connections_set_int_exn max_connections
      *> op validation_queue_size_set_int_exn validation_queue_size
      *> reader_op gating_config_set_reader gating_config)

let create_gating_config ~banned_ips ~banned_peers ~trusted_ips ~trusted_peers
    ~isolate =
  build
    (module Builder.GatingConfig)
    Builder.GatingConfig.(
      list_op banned_ips_set_list banned_ips
      *> list_op banned_peer_ids_set_list banned_peers
      *> list_op trusted_ips_set_list trusted_ips
      *> list_op trusted_peer_ids_set_list trusted_peers
      *> op isolate_set isolate)

let create_rpc_header ~sequence_number =
  build'
    (module Builder.RpcMessageHeader)
    Builder.RpcMessageHeader.(
      reader_op time_sent_set_reader (now ())
      *> reader_op sequence_number_set_reader sequence_number)

let rpc_request_body_set req body =
  let open Builder.Libp2pHelperInterface.RpcRequest in
  match body with
  | Configure b ->
      ignore @@ configure_set_builder req b
  | SetGatingConfig b ->
      ignore @@ set_gating_config_set_builder req b
  | Listen b ->
      ignore @@ listen_set_builder req b
  | GetListeningAddrs b ->
      ignore @@ get_listening_addrs_set_builder req b
  | BeginAdvertising b ->
      ignore @@ begin_advertising_set_builder req b
  | AddPeer b ->
      ignore @@ add_peer_set_builder req b
  | ListPeers b ->
      ignore @@ list_peers_set_builder req b
  | BandwidthInfo b ->
      ignore @@ bandwidth_info_set_builder req b
  | GenerateKeypair b ->
      ignore @@ generate_keypair_set_builder req b
  | Publish b ->
      ignore @@ publish_set_builder req b
  | Subscribe b ->
      ignore @@ subscribe_set_builder req b
  | Unsubscribe b ->
      ignore @@ unsubscribe_set_builder req b
  | AddStreamHandler b ->
      ignore @@ add_stream_handler_set_builder req b
  | RemoveStreamHandler b ->
      ignore @@ remove_stream_handler_set_builder req b
  | OpenStream b ->
      ignore @@ open_stream_set_builder req b
  | CloseStream b ->
      ignore @@ close_stream_set_builder req b
  | ResetStream b ->
      ignore @@ reset_stream_set_builder req b
  | SendStream b ->
      ignore @@ send_stream_set_builder req b
  | SetNodeStatus b ->
      ignore @@ set_node_status_set_builder req b
  | GetPeerNodeStatus b ->
      ignore @@ get_peer_node_status_set_builder req b
  | Undefined _ ->
      failwith "cannot set undefined rpc request body"

let create_rpc_request ~sequence_number body =
  let header = create_rpc_header ~sequence_number in
  build'
    (module Builder.Libp2pHelperInterface.RpcRequest)
    Builder.Libp2pHelperInterface.RpcRequest.(
      builder_op header_set_builder header *> op rpc_request_body_set body)

let rpc_response_to_or_error resp =
  let open Reader.Libp2pHelperInterface.RpcResponse in
  match get resp with
  | Error err ->
      Or_error.error_string err
  | Success body ->
      Or_error.return (Reader.Libp2pHelperInterface.RpcResponseSuccess.get body)
  | Undefined n ->
      undefined_union ~context:"Libp2pHelperInterface.RpcResponse" n

let rpc_request_to_outgoing_message request =
  build'
    (module Builder.Libp2pHelperInterface.Message)
    Builder.Libp2pHelperInterface.Message.(
      builder_op rpc_request_set_builder request)

let create_push_message_header () =
  build'
    (module Builder.PushMessageHeader)
    Builder.PushMessageHeader.(reader_op time_sent_set_reader (now ()))

let push_message_to_outgoing_message request =
  build'
    (module Builder.Libp2pHelperInterface.Message)
    Builder.Libp2pHelperInterface.Message.(
      builder_op push_message_set_builder request)

let create_push_message ~validation_id ~validation_result =
  build'
    (module Builder.Libp2pHelperInterface.PushMessage)
    Builder.Libp2pHelperInterface.PushMessage.(
      builder_op header_set_builder (create_push_message_header ())
      *> reader_op validation_set_reader
           (build
              (module Builder.Libp2pHelperInterface.Validation)
              Builder.Libp2pHelperInterface.Validation.(
                reader_op validation_id_set_reader validation_id
                *> op result_set validation_result)))

(* TODO: a reusable fragment buffer with support for blitting would probably make more sense here (probably not queue-backed) *)
module Fragment_view = struct
  type t = { fragments : bytes list; start_offset : int; end_offset : int }

  type ('result, 'state) decode_f =
       buf:bytes
    -> start:int
    -> end_:int
    -> 'state
    -> [ `Finished of 'result | `Incomplete of 'state ]

  (* maybe this should just be a monad *)
  type 'result decoder =
    | Decoder :
        { size : int
        ; initial_state : 'state
        ; read : ('result, 'state) decode_f
        }
        -> 'result decoder

  let decoder_size (Decoder { size; _ }) = size

  let map_decoder (Decoder d) ~f =
    let read ~buf ~start ~end_ s =
      match d.read ~buf ~start ~end_ s with
      | `Incomplete s' ->
          `Incomplete s'
      | `Finished x ->
          `Finished (f x)
    in
    Decoder { d with read }

  let unsafe_decode (Decoder d) t =
    let fail s = failwithf "Fragment_view.unsafe_decode: %s" s () in
    let decode_from_this_fragment ~start ~end_ ~remaining_bytes ~state fragment
        =
      let finish_expected = end_ - start + 1 >= remaining_bytes in
      match d.read ~buf:fragment ~start ~end_ state with
      | `Finished result when finish_expected ->
          Ok result
      | `Finished result ->
          fail "unexpected completion"
      | `Incomplete st when finish_expected ->
          fail "expected completion"
      | `Incomplete st ->
          Error st
    in
    let rec decode_from_next_fragment ~start ~remaining_bytes ~state
        remaining_fragments =
      let fragment = List.hd_exn remaining_fragments in
      let remaining_fragments' = List.tl_exn remaining_fragments in
      let is_last_fragment = List.is_empty remaining_fragments' in
      let len = Bytes.length fragment in
      let end_ = if is_last_fragment then t.end_offset else len - 1 in
      match
        decode_from_this_fragment ~start ~end_ ~remaining_bytes ~state fragment
      with
      | Ok result ->
          result
      | Error state' ->
          let remaining_bytes' = remaining_bytes - (end_ - start + 1) in
          decode_from_next_fragment ~start:0 ~remaining_bytes:remaining_bytes'
            ~state:state' remaining_fragments'
    in
    decode_from_next_fragment ~start:t.start_offset ~remaining_bytes:d.size
      ~state:d.initial_state t.fragments
end

module Decoders = struct
  open Fragment_view

  let align (Decoder d) alignment =
    let size = alignment * ((d.size + alignment - 1) / alignment) in
    Decoder { d with size }

  let unit : unit decoder =
    Decoder
      { size = 0
      ; initial_state = ()
      ; read = (fun ~buf:_ ~start:_ ~end_:_ () -> `Finished ())
      }

  (* unfortunatley requires copying of bytes, which sucks... *)
  let bytes size : bytes decoder =
    let open struct
      type state =
        { bytes_read : int
        ; accumulator : (bytes * [ `Full | `Slice of int * int ]) list
        }
    end in
    let initial_state = { bytes_read = 0; accumulator = [] } in
    let extract_result slices =
      let result = Bytes.create size in
      assert (
        List.fold_right slices ~init:0 ~f:(fun (buf, slice_view) i ->
            let start, len =
              match slice_view with
              | `Full ->
                  (0, Bytes.length buf)
              | `Slice (start, end_) ->
                  (start, end_ - start + 1)
            in
            Bytes.unsafe_blit ~src:buf ~src_pos:start ~dst:result ~dst_pos:i
              ~len ;
            i + len)
        = size ) ;
      result
    in
    let rec read ~buf ~start ~end_ s =
      if s.bytes_read = size then `Finished (extract_result s.accumulator)
      else
        let required = size - s.bytes_read in
        let available = end_ - start + 1 in
        let slice_size = min required available in
        let slice_end = start + slice_size - 1 in
        let slice_view =
          if start = 0 && slice_end = Bytes.length buf - 1 then `Full
          else `Slice (start, slice_end)
        in
        let bytes_read' = s.bytes_read + slice_size in
        let accumulator' = (buf, slice_view) :: s.accumulator in
        if bytes_read' = size then `Finished (extract_result accumulator')
        else
          `Incomplete { bytes_read = bytes_read'; accumulator = accumulator' }
    in
    Decoder { size; initial_state; read }

  (* TODO: does not test offsets *)
  let%test_unit "bytes decoding" =
    let alphabet = "abcdefghijklmnopqrstuvwxyz" in
    let rec gen_until g f =
      let open Quickcheck.Generator.Let_syntax in
      let%bind x = g in
      if f x then return x else gen_until g f
    in
    let gen =
      let open Quickcheck.Generator.Let_syntax in
      let rec slice_list ~num_slices ~slice_chance ~start ~index src =
        let get () = String.sub src ~pos:start ~len:(index - start + 1) in
        let new_slice () =
          slice_list ~num_slices:(num_slices - 1) ~slice_chance
            ~start:(index + 1) ~index:(index + 1) src
        in
        let continue_slice () =
          slice_list ~num_slices ~slice_chance ~start ~index:(index + 1) src
        in
        if index >= String.length src - 1 then return [ get () ]
        else if num_slices >= String.length src - 1 - index then
          new_slice () >>| List.cons (get ())
        else
          let%bind roll = Float.gen_incl 0.0 1.0 in
          if Float.(roll <= slice_chance) then
            new_slice () >>| List.cons (get ())
          else continue_slice ()
      in
      let%bind n = Int.gen_incl 0 1024 in
      let%bind chars =
        gen_until
          (List.gen_permutations @@ String.to_list alphabet)
          (Fn.compose not List.is_empty)
      in
      let src = String.of_char_list chars in
      let size = String.length src in
      let%bind num_slices = Int.gen_incl 0 (size - 1) in
      let slice_chance =
        Float.of_int (size - 1 - num_slices) /. Float.of_int size
      in
      let%map slices =
        slice_list ~num_slices ~slice_chance ~start:0 ~index:0 src
      in
      List.map slices ~f:Stdlib.Bytes.unsafe_of_string
    in
    Quickcheck.test gen ~f:(fun fragments ->
        let view =
          { Fragment_view.fragments
          ; start_offset = 0
          ; end_offset = Bytes.length @@ List.last_exn fragments
          }
        in
        let size = List.sum (module Int) fragments ~f:Bytes.length in
        let expected =
          fragments
          |> List.map ~f:Stdlib.Bytes.unsafe_to_string
          |> String.concat |> Stdlib.Bytes.unsafe_of_string
        in
        let result = unsafe_decode (bytes size) view in
        [%test_eq: bytes] result expected)

  let uint32 : Uint32.t decoder =
    let open struct
      type state = { bytes_read : int; accumulator : Uint32.t }
    end in
    let size = 4 in
    let initial_state = { bytes_read = 0; accumulator = Uint32.zero } in
    (* read uint32 byte-by-byte for X-fragment solution *)
    let rec read_bytes ~buf ~start ~end_ s =
      if s.bytes_read = size then `Finished s.accumulator
      else
        let b = Bytes.unsafe_get buf start |> Char.to_int |> Uint32.of_int in
        let s' =
          let accumulator =
            Uint32.logor s.accumulator (Uint32.shift_left b (8 * s.bytes_read))
          in
          let bytes_read = s.bytes_read + 1 in
          { bytes_read; accumulator }
        in
        if start = end_ then `Incomplete s'
        else read_bytes ~buf ~start:(start + 1) ~end_ s'
    in
    let read ~buf ~start ~end_ state =
      (* select and optimized solution if possible *)
      if state.bytes_read = 0 && start + size - 1 <= end_ then
        `Finished (Uint32.of_bytes_little_endian buf start)
      else read_bytes ~buf ~start ~end_ state
    in
    Decoder { size; initial_state; read }

  let monomorphic_list (element : 'elt decoder) (count : int) :
      'elt list decoder =
    let (Decoder
          { size = elt_size
          ; initial_state = elt_initial_state
          ; read = read_elt
          }) =
      element
    in
    let open struct
      type ('elt, 'elt_state) state =
        { elements_read : int
        ; element_state : 'elt_state
        ; accumulator : 'elt list
        }
    end in
    let size = elt_size * count in
    let rec read ~buf ~start ~end_ s =
      match read_elt ~buf ~start ~end_ s.element_state with
      | `Incomplete element_state ->
          `Incomplete { s with element_state }
      | `Finished elt ->
          let elements_read = s.elements_read + 1 in
          let accumulator = elt :: s.accumulator in
          if elements_read = count then `Finished (List.rev accumulator)
          else
            let start' = start + elt_size in
            let state' =
              { element_state = elt_initial_state; elements_read; accumulator }
            in
            if start' <= end_ then
              read ~buf ~start:(start + elt_size) ~end_ state'
            else `Incomplete state'
    in
    let initial_state =
      { elements_read = 0; element_state = elt_initial_state; accumulator = [] }
    in
    Decoder { size; initial_state; read }

  let polymorphic_list (elements : 'elt decoder list) : 'elt list decoder =
    let open struct
      type 'elt state =
        | State :
            { current_elt_size : int
            ; read_current_elt : ('elt, 'elt_state) decode_f
            ; current_elt_state : 'elt_state
            ; remaining_elements : 'elt decoder list
            ; accumulator : 'elt list
            }
            -> 'elt state
    end in
    let advance remaining_elements accumulator =
      match remaining_elements with
      | [] ->
          None
      | Decoder
          { size = current_elt_size
          ; initial_state = current_elt_state
          ; read = read_current_elt
          }
        :: remaining_elements ->
          Some
            (State
               { current_elt_size
               ; read_current_elt
               ; current_elt_state
               ; remaining_elements
               ; accumulator
               })
    in
    match advance elements [] with
    | None ->
        map_decoder unit ~f:(Fn.const [])
    | Some initial_state ->
        let size =
          List.sum (module Int) elements ~f:(fun (Decoder { size; _ }) -> size)
        in
        let rec read ~buf ~start ~end_ (State s) =
          match s.read_current_elt ~buf ~start ~end_ s.current_elt_state with
          | `Incomplete current_elt_state ->
              `Incomplete (State { s with current_elt_state })
          | `Finished elt -> (
              let accumulator = elt :: s.accumulator in
              match advance s.remaining_elements accumulator with
              | None ->
                  `Finished (List.rev accumulator)
              | Some s' ->
                  let start' = start + s.current_elt_size in
                  if start' <= end_ then read ~buf ~start:start' ~end_ s'
                  else `Incomplete s' )
        in
        Decoder { size; initial_state; read }
end

module Fragment_stream = struct
  type t =
    { buffered_fragments : bytes Queue.t
    ; mutable buffered_size : int
    ; mutable first_fragment_offset : int
    ; mutable outstanding_read_request : (int * unit Ivar.t) option
    }

  let create () =
    { buffered_fragments = Queue.create ()
    ; buffered_size = 0
    ; first_fragment_offset = 0
    ; outstanding_read_request = None
    }

  let add_fragment t fragment =
    let len = Bytes.length fragment in
    Queue.enqueue t.buffered_fragments fragment ;
    t.buffered_size <- t.buffered_size + len ;
    Option.iter t.outstanding_read_request ~f:(fun (remaining, signal) ->
        let remaining' = remaining - len in
        if remaining' <= 0 then (
          t.outstanding_read_request <- None ;
          Ivar.fill signal () )
        else t.outstanding_read_request <- Some (remaining', signal))

  let read_now_exn t amount_to_read =
    let rec dequeue_fragments amount_read =
      let frag = Queue.peek_exn t.buffered_fragments in
      let len = Bytes.length frag - t.first_fragment_offset in
      let delta_read = min len (amount_to_read - amount_read) in
      let amount_read' = amount_read + delta_read in
      t.buffered_size <- t.buffered_size - delta_read ;
      t.first_fragment_offset <-
        ( if delta_read = len then (
          ignore (Queue.dequeue_exn t.buffered_fragments : bytes) ;
          0 )
        else t.first_fragment_offset + delta_read ) ;
      if amount_read' = amount_to_read then [ frag ]
      else frag :: dequeue_fragments amount_read'
    in
    assert (t.buffered_size >= amount_to_read) ;
    let start_offset = t.first_fragment_offset in
    let fragments = dequeue_fragments 0 in
    let end_offset =
      if t.first_fragment_offset = 0 then
        (* TODO: could use a ref for O(1) access of last fragment instead, should `List.length fragments` be very large *)
        Bytes.length (List.last_exn fragments) - 1
      else t.first_fragment_offset - 1
    in
    { Fragment_view.fragments; start_offset; end_offset }

  let read t amount =
    assert (Option.is_none t.outstanding_read_request) ;
    if t.buffered_size >= amount then return (read_now_exn t amount)
    else
      let amount_required = amount - t.buffered_size in
      let wait_signal = Ivar.create () in
      t.outstanding_read_request <- Some (amount_required, wait_signal) ;
      let%map () = Ivar.read wait_signal in
      read_now_exn t amount

  (* val read_and_decode : Fragment_stream.t -> 'a decoder -> 'a Deferred.t *)
  let read_and_decode t decoder =
    let open Fragment_view in
    read t (decoder_size decoder) >>| unsafe_decode decoder
end

(* TODO: consider -- might be able to re-use bin_ios interface here... *)
let read_and_decode_message t =
  let open Fragment_stream in
  let open Decoders in
  let%bind segment_count = read_and_decode t uint32 >>| Uint32.(( + ) one) in
  (* TODO
     if segment_count-1 > (max_int / 4) - 2 then
       Util.out_of_int_range "Uint32.to_int"
     let frame_header_size =
       let word_size = 8 in
       (Util.ceil_ratio (4 * (segment_count + 1)) word_size) * word_size
     in
  *)
  (* let%bind segment_sizes = read_and_decode t (align (monomorphic_list uint32 (Uint32.to_int segment_count)) 8) in *)
  (* let%bind segment_sizes = read_and_decode t (align (monomorphic_list uint32 (Uint32.to_int (segment_count-1))) 8 + 4) in *)
  let%bind segment_sizes =
    read_and_decode t (monomorphic_list uint32 (Uint32.to_int segment_count))
  in
  let%map segments =
    read_and_decode t
      (polymorphic_list
         (List.map segment_sizes ~f:(fun n -> bytes (Uint32.to_int n * 8))))
  in
  Capnp.BytesMessage.Message.of_storage segments

let rec stream_messages frag_stream w =
  let%bind () =
    read_and_decode_message frag_stream
    >>| Reader.DaemonInterface.Message.of_message >>| Or_error.return
    >>= Strict_pipe.Writer.write w
  in
  stream_messages frag_stream w

let read_incoming_messages reader =
  let r, w = Strict_pipe.create Strict_pipe.Synchronous in
  let fragment_stream = Fragment_stream.create () in
  O1trace.time_execution "ipc_stream_messages" (fun () -> don't_wait_for (stream_messages fragment_stream w)) ;
  O1trace.time_execution "ipc_adding_fragments" (fun () ->
    don't_wait_for
      (Strict_pipe.Reader.iter_without_pushback reader ~f:(fun fragment ->
           Fragment_stream.add_fragment fragment_stream
             (Stdlib.Bytes.unsafe_of_string fragment)))) ;
  r

let write_outgoing_message writer msg =
  msg |> Builder.Libp2pHelperInterface.Message.to_message
  |> Capnp.Codecs.serialize_iter ~compression ~f:(Writer.write writer)
