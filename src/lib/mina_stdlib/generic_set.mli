(** General interface of a Set *)
module type S0 = sig
  type el

  type t

  val empty : t

  val is_empty : t -> bool

  val add : t -> el -> t

  val union : t -> t -> t

  val iter : t -> f:(el -> unit) -> unit

  val equal : t -> t -> bool

  val of_list : el list -> t

  val length : t -> int

  val singleton : el -> t

  val remove : t -> el -> t

  val min_elt_exn : t -> el

  val to_sequence : t -> el Sequence.t
end

(** General interface of a Set with one type parameter *)
module type S1 = sig
  type 'a el

  type 'a t

  val empty : 'a t

  val is_empty : 'a t -> bool

  val add : 'a t -> 'a el -> 'a t

  val union : 'a t -> 'a t -> 'a t

  val iter : 'a t -> f:('a el -> unit) -> unit

  val equal : 'a t -> 'a t -> bool

  val of_list : 'a el list -> 'a t

  val length : 'a t -> int

  val singleton : 'a el -> 'a t

  val remove : 'a t -> 'a el -> 'a t

  val min_elt_exn : 'a t -> 'a el

  val to_sequence : 'a t -> 'a el Sequence.t
end
