(* data_hash.mli -- data hash that uses Snarky *)

module type Full_size =
  Data_hash_functor.Make_sigs(Snark_params.Tick).Full_size

module type Small = Data_hash_functor.Make_sigs(Snark_params.Tick).Small

module Make_small (M : sig
  val length_in_bits : int
end) : Small

module Make_full_size () : Full_size
