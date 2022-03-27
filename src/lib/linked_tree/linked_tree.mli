module type Key = Core_kernel.Hashtbl.Key_plain

module type S = sig
  module Key : Key

  type 'a t

  val add :
       'a t
    -> prev_key:Key.t
    -> key:Key.t
    -> length:Mina_numbers.Length.t
    -> data:'a
    -> [ `Duplicate | `Ok | `Too_old ]

  val path : 'a t -> source:Key.t -> ancestor:Key.t -> 'a list option

  val ancestor_of_depth :
    'a t -> source:Key.t -> depth:int -> (Key.t * 'a list) option

  val create : max_size:int -> 'a t
end

module Make : functor (Key : Key) -> sig
  module Key : sig
    type t = Key.t

    val compare : t -> t -> int

    val sexp_of_t : t -> Base__.Ppx_sexp_conv_lib.Sexp.t

    val hash : t -> int
  end

  type 'a t

  val add :
       'a t
    -> prev_key:Key.t
    -> key:Key.t
    -> length:Mina_numbers.Length.t
    -> data:'a
    -> [ `Duplicate | `Ok | `Too_old ]

  val path : 'a t -> source:Key.t -> ancestor:Key.t -> 'a list option

  val ancestor_of_depth :
    'a t -> source:Key.t -> depth:int -> (Key.t * 'a list) option

  val create : max_size:int -> 'a t
end
