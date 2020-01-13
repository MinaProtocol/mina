(* data_hash.mli *)

module type Small = Data_hash_intf.Small

module type Full_size = Data_hash_intf.Full_size

module Make_small (M : sig
  val length_in_bits : int
end) : Small

module Make_full_size () : Full_size
