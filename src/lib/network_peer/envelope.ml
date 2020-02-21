open Core

module Sender = struct
  type t = Local | Remote of (Unix.Inet_addr.Blocking_sexp.t * Peer.Id.t)
  [@@deriving sexp, compare]

  let of_peer (p : Peer.t) = Remote (p.host, p.peer_id)

  let equal sender1 sender2 = Int.equal (compare sender1 sender2) 0

  let to_yojson t : Yojson.Safe.json =
    match t with
    | Local ->
        `String "Local"
    | Remote (inet_addr, peer_id) ->
        `Assoc
          [ ( "Remote"
            , `Assoc
                [ ("host", `String (Unix.Inet_addr.to_string inet_addr))
                ; ("peer_id", `String (Peer.Id.to_string peer_id)) ] ) ]

  let of_yojson (json : Yojson.Safe.json) : (t, string) Result.t =
    match json with
    | `String "Local" ->
        Ok Local
    | `Assoc
        [ ( "Remote"
          , `Assoc [("host", `String addr); ("peer_id", `String peer_id)] ) ]
      ->
        Ok
          (Remote
             (Unix.Inet_addr.of_string addr, Peer.Id.unsafe_of_string peer_id))
    | _ ->
        Error "Expected JSON representing envelope sender"

  let remote_exn = function
    | Local ->
        failwith "Sender.remote_exn of Local sender"
    | Remote x ->
        x
end

module Incoming = struct
  (* wrapped_at is stored as an int to avoid Time_ns.t missing yojson
     functions or pulling in Real_time from Coda_base (which depends on this library) *)
  type 'a t = {data: 'a; sender: Sender.t; wrapped_at: int}
  [@@deriving eq, sexp, yojson]

  let sender t = t.sender

  let data t = t.data

  let wrapped_at t = t.wrapped_at |> Time_ns.of_int_ns_since_epoch

  let wrap ~data ~sender =
    { data
    ; sender
    ; wrapped_at=
        Time_ns.now () |> Time_ns.to_int63_ns_since_epoch |> Int63.to_int
        |> Option.value_exn }

  let wrap_peer ~data ~sender = wrap ~data ~sender:(Sender.of_peer sender)

  let map ~f t = {t with data= f t.data}

  let local data =
    let sender = Sender.Local in
    wrap ~data ~sender

  let remote_sender_exn t =
    match t.sender with
    | Local ->
        failwith "Incoming.sender_sender_exn of Local envelope"
    | Remote x ->
        x
end
