open Core
open Async

type 'a value = {path: string; value: 'a; checksum: Md5.t}

include Monad.S2

val component
  : label:string
  -> f:('e -> 'a)
  -> 'a Bin_prot.Type_class.t
  -> ('a value, 'e) t

type ('a, 'e) cached = ('a, 'e) t

module Spec : sig
  type 'a t

  val create
    : load:('a, 'env) cached
    -> directory:string
    -> digest_input:('input -> string)
    -> create_env:('input -> 'env)
    -> input:'input
    -> 'a t
end

val run : 'a Spec.t -> 'a Deferred.t
