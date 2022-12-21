(** {1 Predicates over list lengths}*)

module Length : sig
  type 'a t = ('a list, int) Sigs.predicate2

  (** [equal l len] returns [true] if [List.length l = len], [false] otherwise.
   *)
  val equal : 'a t

  (** [gte l len] returns [true] if [List.length l >= len], [false]
    otherwise.
   *)
  val gte : 'a t

  (** [gt l len] returns [true] if [List.length l > len], [false]
    otherwise.
   *)
  val gt : 'a t

  (** [lte l len] returns [true] if [List.length l <= len], [false]
    otherwise.
   *)
  val lte : 'a t

  (** [lt l len] returns [true] if [List.length l < len], [false]
    otherwise.
   p*)
  val lt : 'a t

  (** {2 Infix comparison operators} *)

  (** [Compare] contains infix aliases for functions of {!module:Length} *)
  module Compare : sig
    (** [( = )] is [equal] *)
    val ( = ) : 'a t

    (** [( <> )] is [unequal] *)
    val ( <> ) : 'a t

    (** [( >= )] is [gte] *)
    val ( >= ) : 'a t

    (** [l > len] is [gt] *)
    val ( > ) : 'a t

    (** [( <= )] is [lte] *)
    val ( <= ) : 'a t

    (** [l < len] is [lt] *)
    val ( < ) : 'a t
  end
end
