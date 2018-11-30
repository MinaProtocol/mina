type 'a t

(** This is a FIFO queue of values of type ['a], keyed by their length.
   Say [t : 'a t] has [max_size] [n], [l_old] is the length of the element
   with the smallest length, and [l_new] is the length of the element with
   the largest length.
   
   We maintain the invariant that [l_new - l_old <= n], dequeueing elements
   from the front of the queue if necessary after enqueueing elements.
*)

val create : max_size:int -> 'a t

val push :
     'a t
  -> length:Coda_numbers.Length.t
  -> data:'a
  -> [`Ok | `Length_did_not_increase]
(** Push an element to the queue. The length must be larger than the length of the 
   previously largest element. *)

val push_exn : 'a t -> length:Coda_numbers.Length.t -> data:'a -> unit

val find :
  'a t -> Coda_numbers.Length.t -> [`Known of 'a | `Unknown | `Out_of_bounds]
(** Find an element by its length *)

val find_exn : 'a t -> Coda_numbers.Length.t -> 'a
