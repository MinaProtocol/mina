open Core_kernel

let main () =
  Out_channel.write_all "genesis_filename.txt"
    ~data:
      (Cache_dir.genesis_dir_name ~commit_id_short:Coda_version.commit_id_short) ;
  exit 0

let () = main ()
