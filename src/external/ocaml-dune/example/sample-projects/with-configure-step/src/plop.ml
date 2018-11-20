let () =
  Printf.printf "Built with support for blah: %B\n\
                 Path to blah is:             %S\n"
    Config.with_blah
    Config.blah_path
