open Core_kernel

include module type of List

(** {1 Predicates over list lengths}*)

module Length : sig
  type 'a t = ('a list, int) Sigs.predicate2

  (** [equal l len] returns [true] if [List.length l = len], [false] otherwise.
   *)
  val equal : 'a t

  (** [unequal l len] returns [true] if [List.length l <> len], [false] otherwise.
   *)
  val unequal : 'a t

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

  (** [Compare] contains infix aliases for functions of {!module:Length}. *)
  module Compare : sig
    (** [( = )] is {!val:equal}. *)
    val ( = ) : 'a t

    (** [( <> )] is {!val:unequal}. *)
    val ( <> ) : 'a t

    (** [( >= )] is {!val:gte}. *)
    val ( >= ) : 'a t

    (** [l > len] is {!val:gt}. *)
    val ( > ) : 'a t

    (** [( <= )] is {!val:lte}. *)
    val ( <= ) : 'a t

    (** [l < len] is {!val:lt}. *)
    val ( < ) : 'a t
  end
end

val process_separately :
     partitioner:('input -> ('left, 'right) Base.Either.t)
  -> process_left:('left list -> 'left_output)
  -> process_right:('right list -> 'right_output)
  -> finalizer:
       (   'left_output
        -> 'right_output
        -> f:('output_item list -> 'output_item list -> 'output_item list)
        -> 'final_output )
  -> 'input list
  -> 'final_output
