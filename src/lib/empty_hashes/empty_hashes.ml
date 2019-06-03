open Core

module type Hash_intf = sig
  type t

  val merge : height:int -> t -> t -> t
end

let cache (type hash) (module Hash : Hash_intf with type t = hash)
    ~(init_hash : hash) depth =
  let empty_hashes = Array.create ~len:(depth + 1) init_hash in
  let rec loop last_hash height =
    if height <= depth then (
      let hash = Hash.merge ~height:(height - 1) last_hash last_hash in
      empty_hashes.(height) <- hash ;
      loop hash (height + 1) )
  in
  loop init_hash 1 ;
  Immutable_array.of_array empty_hashes
