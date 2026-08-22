open Core
open Async
open Network_peer

module Snapshot = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        { banned_peers : Peer.Id.Stable.V1.t list
              [@to_yojson
                fun ids -> `List (Core.List.map ids ~f:(fun id -> `String id))]
              [@of_yojson
                function
                | `List ids ->
                    Core.List.map ids ~f:(function
                      | `String s ->
                          Ok s
                      | _ ->
                          Error "expected string" )
                    |> Core.Result.all
                | _ ->
                    Error "expected list"]
        ; banned_ips : Peer.Inet_addr.Stable.V1.t list
        }
      [@@deriving sexp, to_yojson, of_yojson]

      let to_latest = Fn.id
    end
  end]

  let empty = { banned_peers = []; banned_ips = [] }
end

type t =
  { logger : Logger.t
  ; reputation : Handle.t
  ; banned_peers : (Peer.Id.t, Time.t option) Hashtbl.t
  ; banned_ips : (Unix.Inet_addr.t, Time.t option) Hashtbl.t
  }

let create ~logger reputation =
  { logger
  ; reputation
  ; banned_peers = Hashtbl.create (module Peer.Id)
  ; banned_ips = Hashtbl.create (module Unix.Inet_addr)
  }

let set_entries t (entries : Handle.Entry.t list) =
  Hashtbl.clear t.banned_peers ;
  Hashtbl.clear t.banned_ips ;
  List.iter entries ~f:(fun { kind; identity; until } ->
      match kind with
      | Peer_id ->
          Hashtbl.set t.banned_peers
            ~key:(Peer.Id.unsafe_of_string identity)
            ~data:until
      | Ip -> (
          match
            Option.try_with (fun () -> Unix.Inet_addr.of_string identity)
          with
          | Some ip ->
              Hashtbl.set t.banned_ips ~key:ip ~data:until
          | None ->
              [%log' warn t.logger]
                "Ignoring unparseable banned IP $ip reported by libp2p helper"
                ~metadata:[ ("ip", `String identity) ] ) ) ;
  Mina_metrics.Gauge.set Mina_metrics.banned_peers
    (Float.of_int (Hashtbl.length t.banned_peers + Hashtbl.length t.banned_ips))

let refresh t =
  match%map Handle.bans t.reputation with
  | Ok entries ->
      set_entries t entries
  | Error e ->
      [%log' debug t.logger]
        "Could not refresh ban list from libp2p helper: $error"
        ~metadata:[ ("error", Error_json.error_to_yojson e) ]

let start ?(interval = Time.Span.of_sec 30.) t =
  Clock.every' ~continue_on_error:true interval (fun () -> refresh t)

(* The helper lazily drops expired entries, so an expired [until] should never
   arrive; double-check anyway so a stale table never reports a lapsed ban. *)
let still_active = function None -> true | Some until -> Time.(until > now ())

let lookup tbl key =
  match Hashtbl.find tbl key with
  | Some until when still_active until ->
      Some until
  | _ ->
      None

let is_banned_peer t peer_id = Option.is_some (lookup t.banned_peers peer_id)

let is_banned_ip t ip = Option.is_some (lookup t.banned_ips ip)

let is_banned t ~peer_id ~ip =
  is_banned_peer t peer_id
  || Option.value_map ip ~default:false ~f:(is_banned_ip t)

let until_of_peer t peer_id = Option.join (lookup t.banned_peers peer_id)

let until_of_ip t ip = Option.join (lookup t.banned_ips ip)

let snapshot t : Snapshot.t =
  { banned_peers =
      Hashtbl.keys t.banned_peers |> List.filter ~f:(is_banned_peer t)
  ; banned_ips = Hashtbl.keys t.banned_ips |> List.filter ~f:(is_banned_ip t)
  }

let entries t : Handle.Entry.t list =
  let peers =
    Hashtbl.to_alist t.banned_peers
    |> List.filter_map ~f:(fun (peer_id, until) ->
           if still_active until then
             Some
               { Handle.Entry.kind = Peer_id
               ; identity = Peer.Id.to_string peer_id
               ; until
               }
           else None )
  in
  let ips =
    Hashtbl.to_alist t.banned_ips
    |> List.filter_map ~f:(fun (ip, until) ->
           if still_active until then
             Some
               { Handle.Entry.kind = Ip
               ; identity = Unix.Inet_addr.to_string ip
               ; until
               }
           else None )
  in
  peers @ ips
