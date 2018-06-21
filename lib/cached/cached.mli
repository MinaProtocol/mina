open Core
open Async

type 'a t = {path: string; value: 'a; checksum: Md5.t}

val create :
     directory:string
  -> digest_input:('input -> string)
  -> bin_t:'a Bin_prot.Type_class.t
  -> ('input -> 'a)
  -> 'input
  -> 'a t Deferred.t
