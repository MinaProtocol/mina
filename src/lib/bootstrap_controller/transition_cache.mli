type t

val create : unit -> t

val add :
     t
  -> Transition_frontier.Gossip.initial_valid_block_or_header
  -> Transition_frontier.Gossip.gossip_map
  -> unit

val data : t -> Transition_frontier.Gossip.element list
