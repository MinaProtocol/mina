(** Mina PPX layer: PPX deriving and rewriting libraries.

    Each declaration corresponds to a dune file in src/.
    The manifest generates these files from the declarations below. *)

open Manifest
open Externals
open Dune_s_expr

let register () =
  (* -- ppx_annot ------------------------------------------------ *)
  library "ppx_annot" ~path:"src/lib/ppx_annot" ~kind:"ppx_deriver"
    ~deps:[ ppxlib; core_kernel; base; compiler_libs ]
    ~ppx:(Ppx.custom [ "ppx_version"; "ppxlib.metaquot" ]) ;

  (* -- ppx_register_event --------------------------------------- *)
  library "ppx_register_event" ~path:"src/lib/ppx_register_event"
    ~kind:"ppx_deriver"
    ~deps:
      [ ocaml_compiler_libs_common
      ; ppxlib_ast
      ; ppx_deriving_yojson
      ; core_kernel
      ; ppxlib
      ; compiler_libs_common
      ; ocaml_migrate_parsetree
      ; base
      ; local "interpolator_lib"
      ]
    ~ppx:(Ppx.custom [ "ppx_version"; "ppxlib.metaquot" ])
    ~ppx_runtime_libraries:[ "structured_log_events"; "yojson" ] ;

  (* -- ppx_version ---------------------------------------------- *)
  file_stanzas ~path:"src/lib/ppx_version"
    [ "vendored_dirs" @: [ atom "test" ] ] ;
  library "ppx_version" ~path:"src/lib/ppx_version" ~kind:"ppx_deriver"
    ~no_instrumentation:true
    ~deps:
      [ compiler_libs_common
      ; ppxlib
      ; ppxlib_astlib
      ; ppx_derivers
      ; ppx_bin_prot
      ; base
      ; base_caml
      ; core_kernel
      ; ppx_version_runtime
      ; bin_prot
      ]
    ~ppx:(Ppx.custom [ "ppx_compare"; "ppxlib.metaquot" ]) ;

  (* -- ppx_version.runtime -------------------------------------- *)
  library "ppx_version.runtime" ~internal_name:"ppx_version_runtime"
    ~path:"src/lib/ppx_version/runtime" ~no_instrumentation:true
    ~deps:[ base; core_kernel; sexplib0; bin_prot; bin_prot_shape ] ;

  (* -- ppx_mina ------------------------------------------------- *)
  file_stanzas ~path:"src/lib/ppx_mina" [ "vendored_dirs" @: [ atom "tests" ] ] ;
  library "ppx_mina" ~path:"src/lib/ppx_mina" ~kind:"ppx_deriver"
    ~deps:
      [ ppx_deriving_api
      ; ppxlib
      ; ppx_bin_prot
      ; core_kernel
      ; base
      ; base_caml
      ; local "ppx_representatives"
      ; local "ppx_register_event"
      ; local "ppx_to_enum"
      ]
    ~ppx:(Ppx.custom [ "ppx_version"; "ppxlib.metaquot" ]) ;

  (* -- ppx_to_enum ---------------------------------------------- *)
  library "ppx_to_enum" ~path:"src/lib/ppx_mina/ppx_to_enum" ~kind:"ppx_deriver"
    ~deps:[ compiler_libs_common; ppxlib; base ]
    ~ppx:(Ppx.custom [ "ppxlib.metaquot" ]) ;

  (* -- ppx_representatives -------------------------------------- *)
  library "ppx_representatives" ~path:"src/lib/ppx_mina/ppx_representatives"
    ~kind:"ppx_deriver"
    ~deps:
      [ ppxlib_ast
      ; ocaml_compiler_libs_common
      ; compiler_libs_common
      ; ppxlib
      ; base
      ]
    ~ppx:(Ppx.custom [ "ppxlib.metaquot" ])
    ~ppx_runtime_libraries:[ "ppx_representatives.runtime" ] ;

  (* -- ppx_representatives.runtime ------------------------------ *)
  library "ppx_representatives.runtime"
    ~internal_name:"ppx_representatives_runtime"
    ~path:"src/lib/ppx_mina/ppx_representatives/runtime"
    ~no_instrumentation:true ;

  (* -- ppx_mina/tests ------------------------------------------- *)
  private_library "unexpired" ~path:"src/lib/ppx_mina/tests"
    ~ppx:(Ppx.custom [ "ppx_jane"; "ppx_deriving_yojson"; "ppx_mina" ])
    ~modules:[ "unexpired" ] ;
  private_library "define_locally_good" ~path:"src/lib/ppx_mina/tests"
    ~ppx:(Ppx.custom [ "ppx_jane"; "ppx_deriving_yojson"; "ppx_mina" ])
    ~modules:[ "define_locally_good" ] ;
  private_library "define_from_scope_good" ~path:"src/lib/ppx_mina/tests"
    ~ppx:(Ppx.custom [ "ppx_jane"; "ppx_deriving_yojson"; "ppx_mina" ])
    ~modules:[ "define_from_scope_good" ] ;
  private_library "expired" ~path:"src/lib/ppx_mina/tests"
    ~ppx:(Ppx.custom [ "ppx_jane"; "ppx_deriving_yojson"; "ppx_mina" ])
    ~modules:[ "expired" ] ;
  private_library "expiry_in_module" ~path:"src/lib/ppx_mina/tests"
    ~ppx:(Ppx.custom [ "ppx_jane"; "ppx_deriving_yojson"; "ppx_mina" ])
    ~modules:[ "expiry_in_module" ] ;
  private_library "expiry_invalid_date" ~path:"src/lib/ppx_mina/tests"
    ~ppx:(Ppx.custom [ "ppx_jane"; "ppx_deriving_yojson"; "ppx_mina" ])
    ~modules:[ "expiry_invalid_date" ] ;
  private_library "expiry_invalid_format" ~path:"src/lib/ppx_mina/tests"
    ~ppx:(Ppx.custom [ "ppx_jane"; "ppx_deriving_yojson"; "ppx_mina" ])
    ~modules:[ "expiry_invalid_format" ] ;

  ()
