type _ t = ..

type _ t += Fail : 'a t

type response

val unhandled : response

type request =
  | With : { request :'a t; respond : ('a -> response) } -> request

module Handler : sig
  type nonrec t = { with_ : 'a. 'a t -> 'a }

  val create : (request -> response) -> t

  val fail : t

  val extend : t -> t -> t
end
