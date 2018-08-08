module By = Digestif_by
module Bi = Digestif_bi

module type S =
sig
  type ctx
  type kind = [ `SHA224 ]

  val init: unit -> ctx
  val unsafe_feed_bytes: ctx -> By.t -> int -> int -> unit
  val unsafe_feed_bigstring: ctx -> Bi.t -> int -> int -> unit
  val unsafe_get: ctx -> By.t
  val dup: ctx -> ctx
end

module Unsafe : S
= struct
  type kind = [ `SHA224 ]

  open Baijiu_sha256.Unsafe

  type nonrec ctx = ctx

  let init () =
    let b = By.make 128 '\x00' in

    { size = 0L
    ; b
    ; h = [| 0xc1059ed8l
           ; 0x367cd507l
           ; 0x3070dd17l
           ; 0xf70e5939l
           ; 0xffc00b31l
           ; 0x68581511l
           ; 0x64f98fa7l
           ; 0xbefa4fa4l |] }

  let unsafe_get ctx =
    let res = unsafe_get ctx in
    By.sub res 0 28

  let dup = dup
  let unsafe_feed_bytes = unsafe_feed_bytes
  let unsafe_feed_bigstring = unsafe_feed_bigstring
end
