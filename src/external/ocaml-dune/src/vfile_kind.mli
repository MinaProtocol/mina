open Import

module Id : sig
  type 'a t

  val eq : 'a t -> 'b t -> ('a, 'b) Type_eq.t option
end

module type S = sig
  type t

  val id : t Id.t

  val load : Path.t -> t
  val to_string : t -> string
end

type 'a t = (module S with type t = 'a)

val eq : 'a t -> 'b t -> ('a, 'b) Type_eq.t option

module Make
    (T : sig
       type t
       val encode : t Dune_lang.Encoder.t
       val name : string
     end)
  : S with type t = T.t
