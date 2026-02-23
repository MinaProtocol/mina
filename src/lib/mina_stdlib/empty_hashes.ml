open Core_kernel

module type Hash_intf = sig
  type t

  val merge : height:int -> t -> t -> t
end

let merge_hash (type hash) (module Hash : Hash_intf with type t = hash) height
    (last_hash : hash) =
  Hash.merge ~height last_hash last_hash

let cache hash_mod ~init_hash depth =
  let last_hash = ref init_hash in
  Immutable_array.of_array
  @@ Array.init (depth + 1) ~f:(fun i ->
         if Int.equal i 0 then !last_hash
         else (
           last_hash := merge_hash hash_mod (i - 1) !last_hash ;
           !last_hash ) )

let extensible_cache hash_mod ~init_hash =
  let empty_hashes = ref [| init_hash |] in
  fun i ->
    let prev = !empty_hashes in
    let height = Array.length prev - 1 in
    let deficit = i - height in
    ( if deficit > 0 then
      let last_hash = ref (Array.last prev) in
      empty_hashes :=
        Array.append prev
          (Array.init deficit ~f:(fun i ->
               last_hash := merge_hash hash_mod (i + height) !last_hash ;
               !last_hash ) ) ) ;
    !empty_hashes.(i)
