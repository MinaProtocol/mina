(* Embedded rosetta-cli config files.  See [config.mli]. *)

open Core_kernel

type file =
  [ `Config | `Mina_ros | `Mina_no_delegation_ros | `Mina_with_return_funds_ros ]

let filename = function
  | `Config ->
      "config.json"
  | `Mina_ros ->
      "mina.ros"
  | `Mina_no_delegation_ros ->
      "mina-no-delegation-test.ros"
  | `Mina_with_return_funds_ros ->
      "mina-with-return-funds.ros"

let contents = function
  | `Config ->
      Embedded_configs.config_json
  | `Mina_ros ->
      Embedded_configs.mina_ros
  | `Mina_no_delegation_ros ->
      Embedded_configs.mina_no_delegation_test_ros
  | `Mina_with_return_funds_ros ->
      Embedded_configs.mina_with_return_funds_ros

let files : file list =
  [ `Config; `Mina_ros; `Mina_no_delegation_ros; `Mina_with_return_funds_ros ]

let all = List.map files ~f:(fun f -> (f, filename f, contents f))

let find_by_name name =
  List.find files ~f:(fun f -> String.equal (filename f) name)

let names () = String.concat ~sep:", " (List.map files ~f:filename)

let export_to_dir ~dir =
  Or_error.try_with (fun () ->
      if not (try Core.Sys.is_directory_exn dir with _ -> false) then
        Core.Unix.mkdir_p dir ;
      let abs =
        match Core.Filename.realpath dir with p -> p | exception _ -> dir
      in
      List.map files ~f:(fun f ->
          let path = Filename.concat abs (filename f) in
          Out_channel.write_all path ~data:(contents f) ;
          path ) )
