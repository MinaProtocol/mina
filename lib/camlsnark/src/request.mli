type _ t = ..

type _ t += Fail : 'a t

type empty

val unhandled : empty

type request =
  | With : { request :'a t; respond : ('a -> empty) } -> request

module Handler : sig
  type nonrec t = { with_ : 'a. 'a t -> 'a }

  val create : (request -> empty) -> t

  val fail : t

  val extend : t -> t -> t
end
