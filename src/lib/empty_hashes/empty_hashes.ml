open Core

module type Hash_intf = sig
  type t

  val merge : height:int -> t -> t -> t
end

let cache_mutable (type hash) (module Hash : Hash_intf with type t = hash)
    ~(init_hash : hash) depth =
  let empty_hashes = Array.create ~len:(depth + 1) init_hash in
  let rec loop last_hash height =
    if height <= depth then (
      let hash = Hash.merge ~height:(height - 1) last_hash last_hash in
      empty_hashes.(height) <- hash ;
      loop hash (height + 1) )
  in
  loop init_hash 1 ; empty_hashes

let cache hash ~init_hash depth =
  Immutable_array.of_array (cache_mutable hash ~init_hash depth)

let extensible_cache (type hash) (module Hash : Hash_intf with type t = hash)
    ~(init_hash : hash) =
  let empty_hashes = ref [|init_hash|] in
  fun i ->
    let prev = !empty_hashes in
    let deficit = i - Array.length prev + 1 in
    if deficit > 0 then
      empty_hashes :=
        Array.append prev
          (cache_mutable (module Hash) ~init_hash:(Array.last prev) deficit) ;
    !empty_hashes.(i)
