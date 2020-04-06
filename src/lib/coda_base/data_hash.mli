(* data_hash.mli *)

module type Full_size = Data_hash_intf.Full_size

module Make_full_size () : Full_size
