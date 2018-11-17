(** Either a value or an exception *)

type 'a t = ('a, exn) Result.t
