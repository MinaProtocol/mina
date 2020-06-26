(* data_hash.mli *)

module type Full_size = Data_hash_intf.Full_size

module Make_full_size (B58_data : Data_hash_intf.Data_hash_descriptor) :
  Full_size
