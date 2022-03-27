module type S = sig
  type hash

  type elem = [ `Left of hash | `Right of hash ]

  val sexp_of_elem : elem -> Ppx_sexp_conv_lib.Sexp.t

  val elem_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> elem

  val __elem_of_sexp__ : Ppx_sexp_conv_lib.Sexp.t -> elem

  val equal_elem : elem -> elem -> bool

  val elem_hash : elem -> hash

  type t = elem list

  val t_of_sexp : Sexplib0.Sexp.t -> t

  val sexp_of_t : t -> Sexplib0.Sexp.t

  val equal : t -> t -> bool

  val implied_root : t -> hash -> hash

  val check_path : t -> hash -> hash -> bool
end

module Make : functor
  (Hash : sig
     type t

     val t_of_sexp : Sexplib0.Sexp.t -> t

     val sexp_of_t : t -> Sexplib0.Sexp.t

     val merge : height:int -> t -> t -> t

     val equal : t -> t -> bool
   end)
  -> sig
  type elem = [ `Left of Hash.t | `Right of Hash.t ]

  val sexp_of_elem : elem -> Ppx_sexp_conv_lib.Sexp.t

  val elem_of_sexp : Ppx_sexp_conv_lib.Sexp.t -> elem

  val __elem_of_sexp__ : Ppx_sexp_conv_lib.Sexp.t -> elem

  val equal_elem : elem -> elem -> bool

  val elem_hash : elem -> Hash.t

  type t = elem list

  val t_of_sexp : Sexplib0.Sexp.t -> t

  val sexp_of_t : t -> Sexplib0.Sexp.t

  val equal : t -> t -> bool

  val implied_root : t -> Hash.t -> Hash.t

  val check_path : t -> Hash.t -> Hash.t -> bool
end
