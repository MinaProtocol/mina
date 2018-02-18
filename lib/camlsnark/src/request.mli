type _ t = ..

type _ t += Fail : 'a t

type empty

type request =
  | Request : 'a t * ('a -> empty) -> request

module Handler : sig
  type nonrec t = { with_ : 'a. 'a t -> 'a }

  val create : (request -> empty) -> t

  val fail : t

  val extend : t -> t -> t
end
