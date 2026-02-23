(** Multi-key file storage - stores multiple keys with heterogeneous types in a single file *)
open Core_kernel

module Tag : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type ('filename_key, 'a) t

      val compare :
           ('filename_key -> 'filename_key -> int)
        -> ('filename_key, 'a) t
        -> ('filename_key, 'a) t
        -> int

      val equal :
           ('filename_key -> 'filename_key -> bool)
        -> ('filename_key, 'a) t
        -> ('filename_key, 'a) t
        -> bool

      val sexp_of_t :
        ('filename_key -> Sexp.t) -> ('filename_key, 'a) t -> Sexp.t

      val t_of_sexp :
        (Sexp.t -> 'filename_key) -> Sexp.t -> ('filename_key, 'a) t
    end
  end]

  val compare :
       ('filename_key -> 'filename_key -> int)
    -> ('filename_key, 'a) t
    -> ('filename_key, 'a) t
    -> int

  val equal :
       ('filename_key -> 'filename_key -> bool)
    -> ('filename_key, 'a) t
    -> ('filename_key, 'a) t
    -> bool

  val sexp_of_t : ('filename_key -> Sexp.t) -> ('filename_key, 'a) t -> Sexp.t

  val t_of_sexp : (Sexp.t -> 'filename_key) -> Sexp.t -> ('filename_key, 'a) t
end

module type S = Intf.S

include S with type 'a tag = (string, 'a) Tag.t and type filename_key = string

module Make_custom (Inputs : sig
  type filename_key

  val filename : filename_key -> string
end) :
  S
    with type 'a tag = (Inputs.filename_key, 'a) Tag.t
     and type filename_key = Inputs.filename_key
