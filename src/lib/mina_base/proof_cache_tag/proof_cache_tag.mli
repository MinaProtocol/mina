

(* Cache is a storage type depending on proof_cache_tag implementation. From database handle to
   filesystem folder. It introduce more flexibility to the underlying cache implementation *)
module Cache : sig

   type t
   
   (** Initialize the on-disk cache explicitly before interactions with it take place. *)
   val initialize : string -> t
 
 end



type t [@@deriving compare, equal, sexp, yojson, hash]

(* returns proof from cache *)
val unwrap : t -> Cache.t -> Mina_base.Proof.t

(* cache proof by inserting it to storage *)
val generate : Mina_base.Proof.t -> Cache.t -> t


module For_tests : sig 

   val random : unit -> Cache.t

end 