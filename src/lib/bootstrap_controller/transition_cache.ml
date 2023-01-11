open Mina_base
open Core

type t = Transition_frontier.Gossip.element State_hash.Table.t

let create () = State_hash.Table.create ()

let state_hash e =
  State_hash.With_state_hashes.state_hash
  @@ Transition_frontier.Gossip.header_with_hash e

let logger = Logger.create ()

let add (t : t) el gossip_map =
  State_hash.Table.update t (state_hash el) ~f:(function
    | None ->
        (el, `Gossip_map gossip_map)
    | Some (prev_el, `Gossip_map gm) ->
        let gm' =
          String.Map.merge gm gossip_map ~f:(fun ~key:topic -> function
            | `Left v ->
                Some v
            | `Right v ->
                Some v
            | `Both (old_gd, _new_gd) ->
                [%log warn] "Received gossip on topic %s and $state_hash twice"
                  topic
                  ~metadata:
                    [ ("state_hash", State_hash.to_yojson @@ state_hash el) ] ;
                Some old_gd )
        in
        ((match el with `Block _ -> el | _ -> prev_el), `Gossip_map gm') )

let data = State_hash.Table.data
