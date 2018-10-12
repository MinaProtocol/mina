module Nat =
struct
  include Nativeint

  let ( lxor ) = Nativeint.logxor
end

module type BUFFER =
sig
  type t

  val length: t -> int
  val sub: t -> int -> int -> t
  val copy: t -> t

  val benat_to_cpu: t -> int -> nativeint
  val cpu_to_benat: t -> int -> nativeint -> unit
end

let imin (a : int) (b : int) = if a < b then a else b

module Make (B : BUFFER) =
struct
  let size_of_long = Sys.word_size / 8

  (* XXX(dinosaure): I'm not sure about this code. May be we don't need the
                     first loop and the _optimization_ is irrelevant.
   *)
  let xor_into src src_off dst dst_off n =
    let n = ref n in
    let i = ref 0 in

    while !n >= size_of_long
    do
      B.cpu_to_benat
        dst (dst_off + !i)
        Nat.((B.benat_to_cpu dst (dst_off + !i)) lxor (B.benat_to_cpu src (src_off + !i)));

      n := !n - size_of_long;
      i := !i + size_of_long;
    done;

    while !n > 0
    do
      B.cpu_to_benat dst (dst_off + !i)
        Nat.((B.benat_to_cpu src (src_off + !i)) lxor (B.benat_to_cpu dst (dst_off + !i)));
      incr i;
      decr n;
    done

  let xor_into a b n =
    if n > imin (B.length a) (B.length b)
    then raise (Invalid_argument "Baijiu.Xor.xor_inrot: buffers to small")
    else xor_into a 0 b 0 n

  let xor a b =
    let l = imin (B.length a) (B.length b) in
    let r = B.copy (B.sub b 0 l) in
    ( xor_into a r l; r )
end

module Bytes = Make(Digestif_by)
module Bigstring = Make(Digestif_bi)
