open Core
open Async_kernel
open Network_peer

module Kind = struct
  type t = Peer_id | Ip [@@deriving sexp, equal, compare, yojson]

  let to_string = function Peer_id -> "peer_id" | Ip -> "ip"
end

module Entry = struct
  module Time_with_json = struct
    include Time

    let to_yojson tm = `String (Time.to_string_abs tm ~zone:Time.Zone.utc)

    let of_yojson = function
      | `String s ->
          Ok
            (Time.of_string_gen ~if_no_timezone:(`Use_this_one Time.Zone.utc) s)
      | _ ->
          Error "Peer_reputation.Entry: expected time string"
  end

  type t = { kind : Kind.t; identity : string; until : Time_with_json.t option }
  [@@deriving sexp, equal, compare, yojson]
end

type impl =
  { ban :
         manual:bool
      -> peer_id:Peer.Id.t
      -> ip:Unix.Inet_addr.t option
      -> unit Deferred.Or_error.t
  ; unban :
         peer_id:Peer.Id.t
      -> ip:Unix.Inet_addr.t option
      -> unit Deferred.Or_error.t
  ; bans : unit -> Entry.t list Deferred.Or_error.t
  ; trust :
         peer_id:Peer.Id.t
      -> ip:Unix.Inet_addr.t option
      -> unit Deferred.Or_error.t
  ; untrust :
         peer_id:Peer.Id.t
      -> ip:Unix.Inet_addr.t option
      -> unit Deferred.Or_error.t
  ; trusted : unit -> Entry.t list Deferred.Or_error.t
  ; useful : peer_id:Peer.Id.t -> unit
  }

type t = Null | Late of impl Set_once.t

let null_impl =
  let ok ~peer_id:_ ~ip:_ = Deferred.Or_error.return () in
  { ban = (fun ~manual:_ -> ok)
  ; unban = ok
  ; bans = (fun () -> Deferred.Or_error.return [])
  ; trust = ok
  ; untrust = ok
  ; trusted = (fun () -> Deferred.Or_error.return [])
  ; useful = (fun ~peer_id:_ -> ())
  }

let null = Null

let create () = Late (Set_once.create ())

let bind t impl =
  match t with Null -> () | Late cell -> Set_once.set_exn cell [%here] impl

let unbound_error =
  Deferred.Or_error.error_string
    "peer reputation backend not bound (libp2p helper not started)"

let impl_opt = function Null -> None | Late cell -> Set_once.get cell

let with_impl t ~f =
  match t with
  | Null ->
      f null_impl
  | Late cell -> (
      match Set_once.get cell with Some i -> f i | None -> unbound_error )

let ban_manual t ~peer_id ~ip =
  with_impl t ~f:(fun i -> i.ban ~manual:true ~peer_id ~ip)

let unban t ~peer_id ~ip = with_impl t ~f:(fun i -> i.unban ~peer_id ~ip)

let bans t = with_impl t ~f:(fun i -> i.bans ())

let trust t ~peer_id ~ip = with_impl t ~f:(fun i -> i.trust ~peer_id ~ip)

let untrust t ~peer_id ~ip = with_impl t ~f:(fun i -> i.untrust ~peer_id ~ip)

let trusted t = with_impl t ~f:(fun i -> i.trusted ())

let useful t peer_id = Option.iter (impl_opt t) ~f:(fun i -> i.useful ~peer_id)

let ban t ~logger ?(reason = "misbehavior") ?(metadata = []) (peer : Peer.t) =
  [%log warn] "Banning peer $peer: $reason"
    ~metadata:
      ([ ("peer", Peer.to_yojson peer); ("reason", `String reason) ] @ metadata) ;
  don't_wait_for
    ( match%map
        with_impl t ~f:(fun i ->
            i.ban ~manual:false ~peer_id:peer.peer_id ~ip:(Some peer.host) )
      with
    | Ok () ->
        ()
    | Error e ->
        [%log error] "Failed to ban peer $peer: $error"
          ~metadata:
            [ ("peer", Peer.to_yojson peer)
            ; ("error", Error_json.error_to_yojson e)
            ] )

let useful_sender t (sender : Envelope.Sender.t) =
  match sender with Local -> () | Remote peer -> useful t peer.peer_id

let ban_sender t ~logger ?reason ?metadata (sender : Envelope.Sender.t) =
  match sender with
  | Local ->
      [%log debug] "Attempted to ban ourselves: $reason"
        ~metadata:[ ("reason", `String (Option.value reason ~default:"")) ]
  | Remote peer ->
      ban t ~logger ?reason ?metadata peer
