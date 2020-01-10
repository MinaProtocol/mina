open Core

let main () =
  Out_channel.write_all "genesis_filename.txt" ~data:Cache_dir.genesis_dir_name ;
  exit 0

let () = main ()
