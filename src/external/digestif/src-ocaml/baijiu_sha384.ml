module By = Digestif_by
module Bi = Digestif_bi

module type S =
sig
  type ctx
  type kind = [ `SHA384 ]

  val init: unit -> ctx
  val unsafe_feed_bytes: ctx -> By.t -> int -> int -> unit
  val unsafe_feed_bigstring: ctx -> Bi.t -> int -> int -> unit
  val unsafe_get: ctx -> By.t
  val dup: ctx -> ctx
end

module Unsafe : S
= struct
  type kind = [ `SHA384 ]

  open Baijiu_sha512.Unsafe

  type nonrec ctx = ctx

  let init () =
    let b = By.make 128 '\x00' in

    { size = [| 0L; 0L |]
    ; b
    ; h = [| 0xcbbb9d5dc1059ed8L
           ; 0x629a292a367cd507L
           ; 0x9159015a3070dd17L
           ; 0x152fecd8f70e5939L
           ; 0x67332667ffc00b31L
           ; 0x8eb44a8768581511L
           ; 0xdb0c2e0d64f98fa7L
           ; 0x47b5481dbefa4fa4L |] }

  let unsafe_get ctx =
    let res = unsafe_get ctx in
    By.sub res 0 48

  let dup = dup
  let unsafe_feed_bytes = unsafe_feed_bytes
  let unsafe_feed_bigstring = unsafe_feed_bigstring
end
