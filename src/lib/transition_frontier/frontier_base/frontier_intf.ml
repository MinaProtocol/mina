open Coda_base

(** This is the base signature for a full frontier, shared by any implementation
 *  of a full frontier. Currently, this includes the internal [Full_frontier]
 *  and external [Transition_frontier] modules. *)
module type S = sig
  type t

  val find_exn : t -> State_hash.t -> Breadcrumb.t

  val max_length : t -> int

  val consensus_local_state : t -> Consensus.Data.Local_state.t

  val all_breadcrumbs : t -> Breadcrumb.t list

  val root_length : t -> int

  val root : t -> Breadcrumb.t

  val best_tip : t -> Breadcrumb.t

  val best_tip_path : t -> Breadcrumb.t list

  val path_map : t -> Breadcrumb.t -> f:(Breadcrumb.t -> 'a) -> 'a list

  val hash_path : t -> Breadcrumb.t -> State_hash.t list

  val find : t -> State_hash.t -> Breadcrumb.t option

  val find_protocol_state :
    t -> State_hash.t -> Coda_state.Protocol_state.value option

  val successor_hashes : t -> State_hash.t -> State_hash.t list

  val successor_hashes_rec : t -> State_hash.t -> State_hash.t list

  val successors : t -> Breadcrumb.t -> Breadcrumb.t list

  val successors_rec : t -> Breadcrumb.t -> Breadcrumb.t list

  val common_ancestor : t -> Breadcrumb.t -> Breadcrumb.t -> State_hash.t

  val iter : t -> f:(Breadcrumb.t -> unit) -> unit

  val best_tip_path_length_exn : t -> int

  val visualize_to_string : t -> string

  val visualize : filename:string -> t -> unit

  val precomputed_values : t -> Precomputed_values.t

  val genesis_constants : t -> Genesis_constants.t
end
