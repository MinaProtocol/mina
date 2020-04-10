open Core_kernel

let main genesis_constants =
  Out_channel.write_all "genesis_filename.txt"
    ~data:
      (Cache_dir.genesis_dir_name ~commit_id_short:Coda_version.commit_id_short
         genesis_constants) ;
  exit 0

let () = main Genesis_constants.compiled
