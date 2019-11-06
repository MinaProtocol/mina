open Core
open Async

type 'a value = {path: string; value: 'a; checksum: Md5.t}

include Applicative.S2

module Let_syntax : sig
  val return : 'a -> ('a, 'e) t

  module Let_syntax : sig
    val return : 'a -> ('a, 'e) t

    val map : ('a, 'e) t -> f:('a -> 'b) -> ('b, 'e) t

    val both : ('a, 'e) t -> ('b, 'e) t -> ('a * 'b, 'e) t

    module Open_on_rhs : sig end
  end
end

val component :
  label:string -> f:('e -> 'a) -> 'a Binable.m -> ('a value, 'e) t

type ('a, 'e) cached = ('a, 'e) t

module Spec : sig
  type 'a t

  val create :
       load:('a, 'env) cached
    -> name:string
    -> autogen_path:string
    -> manual_install_path:string
    -> brew_install_path:string
    -> s3_install_path:string
    -> digest_input:('input -> string)
    -> create_env:('input -> 'env)
    -> input:'input
    -> 'a t
end

(** A Semigroup for tracking the "dirty bit" of whether or not we've generated
 * something or only received cache hits *)
module Track_generated : sig
  type t = [`Generated_something | `Cache_hit]

  val ( + ) : t -> t -> t
  (** Generated_something overrides caches hits *)
end

val run : 'a Spec.t -> ('a * Track_generated.t) Deferred.t
