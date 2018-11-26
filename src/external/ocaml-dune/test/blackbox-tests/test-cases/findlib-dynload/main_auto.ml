let () = print_endline "m: init"

let () = Findlib.init ()
let () =
  let pkgs = Fl_package_base.list_packages () in
  let pkgs =
    List.filter
      (fun pkg -> 14 <= String.length pkg && String.sub pkg 0 14 = "mytool-plugin-")
      pkgs
  in
  Fl_dynload.load_packages pkgs
