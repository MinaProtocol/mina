type _ t = ..

type _ t += Fail : 'a t

type 'a req = 'a t

type response

val unhandled : response

module Response : sig
  type nonrec 'a t = Provide of 'a | Reraise of 'a t | Unhandled
end

type request =
  | With : {request: 'a t; respond: 'a Response.t -> response} -> request

module Handler : sig
  type single

  type t

  val fail : t

  val create_single : (request -> response) -> single

  val push : t -> single -> t

  val run : t -> 'a req -> 'a
end
