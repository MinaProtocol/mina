open Core

module Sender = struct
  type t = Local | Remote of Peer.t [@@deriving sexp, compare]

  let of_peer (p : Peer.t) = Remote p

  let equal sender1 sender2 = Int.equal (compare sender1 sender2) 0

  let to_yojson t : Yojson.Safe.t =
    match t with
    | Local ->
        `String "Local"
    | Remote p ->
        `Assoc [("Remote", Peer.to_yojson p)]

  let of_yojson (json : Yojson.Safe.t) : (t, string) Result.t =
    match json with
    | `String "Local" ->
        Ok Local
    | `Assoc [("Remote", peer_json)] ->
        let open Result.Let_syntax in
        let%map peer = Peer.of_yojson peer_json in
        Remote peer
    | _ ->
        Error "Expected JSON representing envelope sender"

  let remote_exn = function
    | Local ->
        failwith "Sender.remote_exn of Local sender"
    | Remote x ->
        x

  let gen : t Quickcheck.Generator.t =
    let open Quickcheck.Generator.Let_syntax in
    let%bind ip =
      match%map
        Quickcheck.Generator.(
          variant2
            (list_with_length 4 (Int.gen_incl 0 255))
            (list_with_length 8 (Int.gen_incl 0 65535)))
      with
      | `A octets ->
          String.concat ~sep:"." (List.map ~f:Int.to_string octets)
      | `B segments ->
          String.concat ~sep:":" (List.map ~f:(Printf.sprintf "%x") segments)
    in
    let remote =
      let inet = Unix.Inet_addr.of_string ip in
      let%bind peer_id = String.gen_nonempty in
      let%map libp2p_port = Int.gen_uniform_incl 1025 49151 in
      Peer.create inet ~peer_id ~libp2p_port
    in
    match%map Option.quickcheck_generator remote with
    | None ->
        Local
    | Some remote ->
        Remote remote
end

module Incoming = struct
  type 'a t = {data: 'a; sender: Sender.t}
  [@@deriving eq, sexp, yojson, compare]

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

  let gen gen_a =
    let open Quickcheck.Generator.Let_syntax in
    let%bind data = gen_a in
    let%map sender = Sender.gen in
    {data; sender}
end
