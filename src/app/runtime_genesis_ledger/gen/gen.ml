open Core

let main genesis_constants =
  Out_channel.write_all "genesis_filename.txt"
    ~data:
      (Cache_dir.genesis_dir_name ~genesis_constants
         ~proof_level:Genesis_constants.Proof_level.compiled) ;
  exit 0

let () = main Genesis_constants.compiled
