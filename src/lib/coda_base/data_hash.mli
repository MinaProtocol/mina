open Data_hash_intf

module type Basic = Basic

module type Full_size = Full_size

module type Small = Small

module Make_small (M : sig
  val length_in_bits : int
end) : Small

module Make_full_size () : Full_size
