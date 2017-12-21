open Core_kernel
open Async_kernel

module type S = sig
  type t

  val connect
    : initial_peers:Peer.t list -> t

  val peers : t -> Peer.t list

  val changes : t -> Peer.Event.t Pipe.Reader.t
end

module Messager (Payload : sig
  type t [@@deriving bin_io]
end)
(* TODO imeckler for bkase: Can we give this a more descriptive name? I have no idea what the intention is
   from reading the signature *)
    (Contextual : sig
  type t

  type ctx [@@deriving bin_io]

  (* TODO: Reviewer: I don't like that this is mutable, but I think it make sense
   * the concrete impl for swim will take information about a set of nodes being
   * dead or alive and merge it into some collection in a special order to get
   * Round-Robin extension benefits of the algorithm.
   *
   * Can't think of a nice way to make this immutable since it changes
   * asynchronously when messages come in.
   *)
  val add : t -> ctx -> unit

  val get : t -> ctx
end) : (sig
  type t

(* TODO imeckler for bkase: You have to expose the definition of [ackable] or else it will be impossible
   to construct hte [incoming_stream] you need to hand to [create] *)
  type 'a ackable [@@deriving bin_io]

  type incoming_stream = (Host_and_port.t * Payload.t ackable * Contextual.ctx) Pipe.Reader.t
  type outgoing_stream = (Payload.t ackable * Contextual.ctx) Pipe.Writer.t

  val create : timeout:Time.Span.t
    -> incoming_stream
    -> Contextual.t
    (* to send messages *)
    -> (Host_and_port.t -> outgoing_stream option Deferred.t)
    (* handle incoming msgs *)
    -> (Payload.t -> unit Deferred.t)
    -> t

  val send : t -> Host_and_port.t -> Payload.t -> [ `Failed | `Acked ] Deferred.t
end) = struct
  (* TODO imeckler for bkase: What do you think of
     module Request_or_ack = struct
      type 'a t = Ack | Request of 'a [@@deriving bin_io]
     end *)

  type 'a ackable = Ack | Req of 'a [@@deriving bin_io]

  type incoming_stream = (Host_and_port.t * Payload.t ackable * Contextual.ctx) Pipe.Reader.t
  type outgoing_stream = (Payload.t ackable * Contextual.ctx) Pipe.Writer.t

  type t =
    { table : unit Ivar.t Host_and_port.Table.t
    ; contextual : Contextual.t
    (* TODO imeckler for bkase: How about, [open_outgoing] (and have it return an [Or_error.t] instead of an option)? *)
    ; outgoing : Host_and_port.t -> outgoing_stream option Deferred.t
    (* TODO(bkase): Remember to handle different msgs having diff timeouts *)
    ; timeout : Time.Span.t
    }

  let raw_send t addr ackable_msg before_send : _ Deferred.t =
    (* TODO imeckler for bkase: You can just use [Let_syntax] if you want (Async brings it in scope). I don't fell
    strongly either way. *)
    let open Deferred.Let_syntax in
    (* TODO: Reviewer: Do I understand the semantics of write well?
       imeckler: Not sure how to answer -- could you say more about your intention?
    *)
    (* TODO imeckler for bkase: How about
       [outgoing] should return [None] if pipe open fails *)
    (* Assuming if pipe open fails we'll hit the None case *)
    match%bind (t.outgoing addr) with
    | Some stream ->
      (* TODO: Reviewer with_timeout is deprecated in this module, but can't find the real one *)
        let res = before_send () in
        (* TODO imeckler for bkase: I changed this to use Let_syntax (which I think in general should be preferred).
           The thinking is that code should be uniform and explicit. Let me know what you think.
           You can delete this once you read it. *)
        let%bind () = Pipe.write stream (ackable_msg, (Contextual.get t.contextual)) in
        res
    | None -> return `Failed

  let create ~timeout incoming contextual outgoing handle_msg =
    let table = Host_and_port.Table.create () in
    (* TODO imeckler for bkase: Change to
      let t =
        { table
        ; contextual
        ; outgoing
        ; timeout
        }
      in *)
    let t = { table
            ; contextual
            ; outgoing
            ; timeout
            } in
    (* TODO: Consider using the 'a Queue version for efficiency
       imeckkler: My guess would be it's not necessary, but feel free to.
    *)
    don't_wait_for begin
      (* TODO imeckler for bkase: Is not pushing back the right thing to do?
         (I changed to [iter_without_pushback] because that was what this was doing anyway)
      *)
      Pipe.iter_without_pushback incoming (fun (from, p, ctx) ->
        Contextual.add contextual ctx;
        let open Deferred.Let_syntax in
        match p with
        | Req x ->
           (* TODO: Reviewer: If we don't_wait_for here, then we could overload
            * system resources (open sockets etc) if we receive packets faster than
            * we can send them.
            *
            * On the other side, if we wait then we certainly will be overloaded
            * with incoming packets and we won't respond fast enough.
            *
            * This may have to get more complex to properly handle flow control,
            * but I think that udp packates should be sent fast enough that it
            * should be okay?

              imeckler: Yeah this is tricky. Let's leave it as is for now I think.
            *)
           don't_wait_for begin
             let%bind wait_handle_msg = handle_msg x in
             let%map _ = raw_send t from Ack (fun () -> return `Failed) in
             ()
           end
        | Ack ->
          (* TODO imeckler for bkase:
             Consider using Option.iter now that it's no longer deferred *)
          match Host_and_port.Table.find t.table from with
          | Some ivar ->
              Ivar.fill_if_empty ivar ();
              Host_and_port.Table.remove t.table from
          | None -> ()
      )
    end;
    t

  let send t addr msg =
    let open Deferred.Let_syntax in
    let wait_ack = raw_send t addr (Req msg) (fun () ->
      Deferred.map ~f:(fun () -> `Acked) (Deferred.create (fun ivar ->
        Host_and_port.Table.set ~key:addr t.table ~data:ivar
      ))
    ) in
    (* TODO imeckler for bkase: Are we triing to make this only depend on [core_kernel] and
       [async_kernel] and not on Core/Async? [Async.with_timeout] is the [Time.Span.t] version.
       And async_kernel has the [Time_ns.Span.t] version for whatever reason. Probably switch to
       the async_kernel one, no? And I'm not sure the story on using [Time_ns] vs [Time]. I remember in
       the past (core|async)_kernel didn't have Time and only had Time_ns but that seems to have changed.  *)
    match%map Core.Std.with_timeout t.timeout wait_ack with
    | `Timeout ->
        Host_and_port.Table.remove t.table addr;
        `Failed
    | `Result () -> `Acked

end

module Udp : S = struct
  type t

  let connect ~initial_peers = failwith "TODO"

  let peers t = failwith "TODO"

  let changes t = failwith "TODO"
end
