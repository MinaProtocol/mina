type 'a t = [ `One of 'a | `Two of 'a * 'a ]

(** One_or_two operations in a two-parameter monad. *)
module type Monadic2 = sig
  type ('a, 'e) m

  val sequence : ('a, 'e) m t -> ('a t, 'e) m

  val map : 'a t -> f:('a -> ('b, 'e) m) -> ('b t, 'e) m

  (** [map_biased t ~f] would map on all element inside a One_or_two, but the caller
      could discriminate on each element based on their position in the One_or_two.
      If t is `One a, this will return `One (f `One a);
      If t is `Two (a, b), this would return `Two (f `First a, f `Second b);
   *)
  val map_biased :
    'a t -> f:([ `One | `First | `Second ] -> 'a -> ('b, 'e) m) -> ('b t, 'e) m

  val fold :
    'a t -> init:'accum -> f:('accum -> 'a -> ('accum, 'e) m) -> ('accum, 'e) m
end

(** One_or_two operations in a single parameter monad. *)
module type Monadic = sig
  type 'a m

  include Monadic2 with type ('a, 'e) m := 'a m
end
