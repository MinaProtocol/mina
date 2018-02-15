type _ t = ..

type _ t += Fail : 'a t

module Handler : sig
  type nonrec t = { handle : 'a. 'a t -> 'a }

  val fail : t

  val extend : t -> t -> t
end
