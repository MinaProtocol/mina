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
  label:string -> f:('e -> 'a) -> 'a Bin_prot.Type_class.t -> ('a value, 'e) t

type ('a, 'e) cached = ('a, 'e) t

module Spec : sig
  type 'a t

  val create :
       load:('a, 'env) cached
    -> name:string
    -> autogen_path:string
    -> manual_install_path:string
    -> digest_input:('input -> string)
    -> create_env:('input -> 'env)
    -> input:'input
    -> 'a t
end

val run : 'a Spec.t -> 'a Deferred.t
