open Mina_base
open Core
open Network_peer

type initial_valid_block_or_header =
  | Block of Mina_block.initial_valid_block
  | Header of Mina_block.initial_valid_header

type element =
  initial_valid_block_or_header Envelope.Incoming.t
  * Mina_net2.Validation_callback.t option

let header_with_hash e =
  match e with
  | Block b ->
      With_hash.map ~f:Mina_block.header
      @@ Mina_block.Validation.block_with_hash b
  | Header h ->
      Mina_block.Validation.header_with_hash h

(* Cache represents a graph. The key is a State_hash, which is the node in
   the graph, and the value is the children transitions of the node *)

type t = element list State_hash.Table.t

let create () = State_hash.Table.create ()

let state_hash e =
  State_hash.With_state_hashes.state_hash @@ header_with_hash
  @@ Envelope.Incoming.data e

let logger = Logger.create ()

let merge (old_env, old_vc) (new_env, new_vc) =
  let old_b = Envelope.Incoming.data old_env in
  let vc =
    match (old_vc, new_vc) with
    | Some _, Some _ ->
        [%log warn] "Received gossip on $state_hash twice"
          ~metadata:
            [ ("state_hash", State_hash.to_yojson @@ state_hash old_env) ] ;
        old_vc
    | None, Some _ ->
        new_vc
    | _ ->
        old_vc
  in
  ( Envelope.Incoming.map new_env ~f:(fun new_b ->
        match new_b with Block _ -> new_b | _ -> old_b )
  , vc )

let add (t : t) ~parent new_child =
  State_hash.Table.update t parent ~f:(function
    | None ->
        [ new_child ]
    | Some children ->
        let children', b =
          List.fold children ~init:([], false) ~f:(fun (acc, b) child ->
              if
                (not b)
                && State_hash.equal
                     (state_hash @@ fst child)
                     (state_hash @@ fst new_child)
              then (merge child new_child :: acc, true)
              else (acc, b) )
        in
        if b then children' else new_child :: children )

let data t =
  let collected_transitions = State_hash.Table.data t |> List.concat in
  assert (
    List.length collected_transitions
    = List.length (List.stable_dedup collected_transitions) ) ;
  collected_transitions
