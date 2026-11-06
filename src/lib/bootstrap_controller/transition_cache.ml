open Mina_base
open Core
open Network_peer

type initial_valid_block_or_header =
  [ `Block of Mina_block.initial_valid_block
  | `Header of Mina_block.initial_valid_header ]

type element =
  initial_valid_block_or_header Envelope.Incoming.t
  * Mina_net2.Validation_callback.t option

let header_with_hash e =
  match e with
  | `Block b ->
      With_hash.map ~f:Mina_block.header
      @@ Mina_block.Validation.block_with_hash b
  | `Header h ->
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
        match new_b with `Block _ -> new_b | _ -> old_b )
  , vc )

(** [children] with [new_child] merged into the child [equal] to it, or added
    if there is none. *)
let add_child ~equal ~merge children new_child =
  let children', b =
    List.fold children ~init:([], false) ~f:(fun (acc, b) child ->
        (* If state hash was already among children, existing child is
           merged with the new transition.
           It's needed to maintain consistency about transitions that may
           come from gossip or other ways; we want to preserve some
           validation callback (and we don't expect two gossips for the
           same).
           Also, if we received a block after receiving a header
           (possible when we'll simultaneously support both old and new
           gossip topics), we want to preserve a block because it's more
           than a header. *)
        if (not b) && equal child new_child then
          (merge child new_child :: acc, true)
        else (child :: acc, b) )
  in
  if b then children' else new_child :: children

let add (t : t) ~parent new_child =
  State_hash.Table.update t parent ~f:(fun children ->
      add_child
        ~equal:(fun x y ->
          State_hash.equal (state_hash @@ fst x) (state_hash @@ fst y) )
        ~merge
        (Option.value children ~default:[])
        new_child )

let data t =
  let collected_transitions = State_hash.Table.data t |> List.concat in
  assert (
    Stdlib.List.compare_lengths collected_transitions
      (List.stable_dedup collected_transitions)
    = 0 )
  (* TODO: make this assertion more efficient *) ;
  collected_transitions

let%test_module "Adding to the transition cache" =
  ( module struct
    let add_child =
      add_child
        ~equal:(fun (x, _) (y, _) -> Int.equal x y)
        ~merge:(fun (x, old) (_, new_) -> (x, old ^ new_))

    let sorted = List.sort ~compare:[%compare: int * string]

    let%test_unit "A child already present is merged, and its siblings kept" =
      [%test_eq: (int * string) list]
        (sorted (add_child [ (1, "a"); (2, "b"); (3, "c") ] (2, "d")))
        [ (1, "a"); (2, "bd"); (3, "c") ]

    let%test_unit "A new child is added" =
      [%test_eq: (int * string) list]
        (sorted (add_child [ (1, "a") ] (2, "b")))
        [ (1, "a"); (2, "b") ]
  end )
