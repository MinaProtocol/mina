open Mina_base

(** This is the base signature for a full frontier, shared by any implementation
 *  of a full frontier. Currently, this includes the internal [Full_frontier]
 *  and external [Transition_frontier] modules. *)
module type S = sig
  type t

  val max_length : t -> int

  val consensus_local_state : t -> Consensus.Data.Local_state.t

  val all_state_hashes : t -> State_hash.t list

  val all_breadcrumbs : t -> Breadcrumb.t list

  val root_length : t -> int

  (* Primary needed for consensus state *)
  val root : t -> Breadcrumb.t

  val best_tip : t -> Breadcrumb.t

  val best_tip_path : ?max_length:int -> t -> Breadcrumb.t list

  val path_map :
    ?max_length:int -> t -> Breadcrumb.t -> f:(Breadcrumb.t -> 'a) -> 'a list

  val hash_path : t -> Breadcrumb.t -> State_hash.t list

  val find : t -> State_hash.t -> Breadcrumb.t option

  val find_protocol_state :
    t -> State_hash.t -> Mina_state.Protocol_state.value option

  (** The ledger with the given hash below the root's, if any: the snarked
      ledgers that the proofs of the root's scan state will target, and the
      ledgers of former roots between them. *)
  val find_ledger_below_root : t -> Ledger_hash.t -> Mina_ledger.Ledger.t option

  val successors : t -> Breadcrumb.t -> Breadcrumb.t list

  val best_tip_path_length_exn : t -> int

  val visualize_to_string : t -> string

  val visualize : filename:string -> t -> unit

  (** Write a graph of the masks of the frontier's breadcrumbs. *)
  val visualize_masks : filename:string -> t -> unit

  val precomputed_values : t -> Precomputed_values.t

  val genesis_constants : t -> Genesis_constants.t
end
