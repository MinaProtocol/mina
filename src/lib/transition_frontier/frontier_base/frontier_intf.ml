open Coda_base

module type S = sig
  type t [@@deriving eq]

  val find_exn : t -> State_hash.t -> Breadcrumb.t

  val get_root : t -> Breadcrumb.t option

  val get_root_exn : t -> Breadcrumb.t

  val max_length : t -> int

  val consensus_local_state : t -> Consensus.Data.Local_state.t

  val all_breadcrumbs : t -> Breadcrumb.t list

  val all_user_commands : t -> User_command.Set.t

  val root : t -> Breadcrumb.t

  val root_length : t -> int

  val best_tip : t -> Breadcrumb.t

  val best_tip_path : t -> Breadcrumb.t list

  val path_map : t -> Breadcrumb.t -> f:(Breadcrumb.t -> 'a) -> 'a list

  val hash_path : t -> Breadcrumb.t -> State_hash.t list

  val find : t -> State_hash.t -> Breadcrumb.t option

  val successor_hashes : t -> State_hash.t -> State_hash.t list

  val successor_hashes_rec : t -> State_hash.t -> State_hash.t list

  val successors : t -> Breadcrumb.t -> Breadcrumb.t list

  val successors_rec : t -> Breadcrumb.t -> Breadcrumb.t list

  val common_ancestor : t -> Breadcrumb.t -> Breadcrumb.t -> State_hash.t

  val iter : t -> f:(Breadcrumb.t -> unit) -> unit

  val best_tip_path_length_exn : t -> int

  val shallow_copy_root_snarked_ledger : t -> Ledger.Mask.Attached.t

  val visualize_to_string : t -> string

  val visualize : filename:string -> t -> unit
end
