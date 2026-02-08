(** Mina node layer: node configuration and runtime settings.

    Each declaration corresponds to a dune file in src/.
    The manifest generates these files from the declarations below. *)

open Manifest
open Externals

let register () =
  (* -- mina_node_config.intf -------------------------------------- *)
  library "mina_node_config.intf" ~internal_name:"node_config_intf"
    ~path:"src/lib/node_config/intf"
    ~modules_without_implementation:[ "node_config_intf" ]
    ~ppx:(Ppx.custom [ "ppx_version"; "ppx_base" ]) ;

  (* -- mina_node_config ------------------------------------------- *)
  library "mina_node_config" ~internal_name:"node_config"
    ~path:"src/lib/node_config"
    ~deps:
      [ local "node_config_intf"
      ; local "node_config_version"
      ; local "node_config_unconfigurable_constants"
      ; local "node_config_profiled"
      ]
    ~ppx:(Ppx.custom [ "ppx_version"; "ppx_base" ]) ;

  (* -- mina_node_config.for_unit_tests ---------------------------- *)
  library "mina_node_config.for_unit_tests"
    ~internal_name:"node_config_for_unit_tests"
    ~path:"src/lib/node_config/for_unit_tests"
    ~deps:
      [ local "node_config_intf"
      ; local "node_config_version"
      ; local "node_config_unconfigurable_constants"
      ]
    ~ppx:(Ppx.custom [ "ppx_version"; "ppx_base" ]) ;

  (* -- mina_node_config.profiled ---------------------------------- *)
  library "mina_node_config.profiled" ~internal_name:"node_config_profiled"
    ~path:"src/lib/node_config/profiled"
    ~deps:[ core_kernel; local "comptime"; local "node_config_intf" ]
    ~ppx:Ppx.minimal ;

  (* -- mina_node_config.unconfigurable_constants ------------------ *)
  library "mina_node_config.unconfigurable_constants"
    ~internal_name:"node_config_unconfigurable_constants"
    ~path:"src/lib/node_config/unconfigurable_constants"
    ~deps:[ local "node_config_intf" ]
    ~ppx:(Ppx.custom [ "ppx_version"; "ppx_base" ]) ;

  (* -- mina_node_config.version ----------------------------------- *)
  library "mina_node_config.version" ~internal_name:"node_config_version"
    ~path:"src/lib/node_config/version"
    ~deps:[ local "node_config_intf" ]
    ~ppx:(Ppx.custom [ "ppx_version"; "ppx_base" ]) ;

  ()
