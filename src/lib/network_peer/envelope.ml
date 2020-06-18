open Core

module Sender = struct
  type t = Local | Remote of (Unix.Inet_addr.Blocking_sexp.t * Peer.Id.t)
  [@@deriving sexp, compare]

  let of_peer (p : Peer.t) = Remote (p.host, p.peer_id)

  let equal sender1 sender2 = Int.equal (compare sender1 sender2) 0

  let to_yojson t : Yojson.Safe.t =
    match t with
    | Local ->
        `String "Local"
    | Remote (inet_addr, peer_id) ->
        `Assoc
          [ ( "Remote"
            , `Assoc
                [ ("host", `String (Unix.Inet_addr.to_string inet_addr))
                ; ("peer_id", `String (Peer.Id.to_string peer_id)) ] ) ]

  let of_yojson (json : Yojson.Safe.t) : (t, string) Result.t =
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
  type 'a t = {data: 'a; sender: Sender.t} [@@deriving eq, sexp, yojson]

  let sender t = t.sender

  let data t = t.data

  let wrap ~data ~sender = {data; sender}

  let wrap_peer ~data ~sender = {data; sender= Sender.of_peer sender}

  let map ~f t = {t with data= f t.data}

  let local data =
    let sender = Sender.Local in
    {data; sender}

  let remote_sender_exn t =
    match t.sender with
    | Local ->
        failwith "Incoming.sender_sender_exn of Local envelope"
    | Remote x ->
        x
end
