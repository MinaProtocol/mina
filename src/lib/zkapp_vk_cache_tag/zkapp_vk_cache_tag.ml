module Cache = Disk_cache.Make (Verification_key_wire.Stable.Latest)

type cache_db = Cache.t

type t = Cache.id

let read_key_from_disk = Cache.get 

let write_key_to_disk =  Cache.put 

let create_db path ~logger = Cache.initialize ~logger path
