(* bin_io_unversioned *)

(* use [@@deriving bin_io_unversioned] for serialized types that
   are not send to nodes or persisted, namely the daemon RPC
   types for communication between the client and daemon, which
   are known to be running the same version of the software.

   The deriver here calls the derivers for bin_io after the lint
   phase. We avoid linter errors that would occur if
   we used [@@deriving bin_io] directly.
*)

open Core_kernel
open Ppxlib
open Versioned_util

let deriver = "bin_io_unversioned"

let bin_io_gens :
    (   ctxt:Expansion_context.Deriver.t
     -> rec_flag * type_declaration list
     -> structure_item list)
    list =
  List.map ["bin_read"; "bin_write"; "bin_type_class"; "bin_shape"]
    ~f:(fun name ->
      let deriver = Option.value_exn (Ppx_derivers.lookup name) in
      (* deriver is an instance of Ppxlib.Deriving.Deriver.deriver

           if instead we consider it to be an instance of Ppx_deriving.t, the 0th
           field, which should be the name, but prints out as garbage

           the 0th field of deriver is a string "Ppxlib__Deriving.Deriver.T", perhaps an artifact
             of the += type extension
           the 1st field of deriver appears to be of type Ppxlib.Deriving.Deriver.t, and the 0th field
             of that gives us an Actual_deriver.t

           the 0th field of the Actual_deriver.t should be the name, which prints out as
             expected

           the number of fields of the Actual_deriver.t is 8, which corresponds to the type
             definition

           from the Actual_deriver.t, we pull out the 1st field, the Generator.t with the label
             str_type_decl; it has 5 fields, corresponding to the GADT definition

           from the Generator.t, we pull out the first field, which is the expander we want to apply

        *)
      let actual_deriver = Obj.(obj (field (field (repr deriver) 1) 0)) in
      let name = Obj.(obj (field (repr actual_deriver) 0)) in
      eprintf "DERIVER NAME: %s\n%!" name ;
      eprintf "NUM ACTUAL DERIVER FIELDS: %d\n%!"
        Obj.(size (repr actual_deriver)) ;
      let generator :
          (structure, rec_flag * type_declaration list) Deriving.Generator.t =
        Option.value_exn Obj.(obj (field (repr actual_deriver) 1))
      in
      eprintf "NUM GENERATOR FIELDS: %d\n%!" Obj.(size (repr generator)) ;
      let gen :
             ctxt:Expansion_context.Deriver.t
          -> rec_flag * type_declaration list
          -> structure_item list =
        Obj.(obj (field (repr generator) 1))
      in
      gen )

let validate_type_decl inner2_modules type_decl =
  match inner2_modules with
  | [module_version; "Stable"] ->
      let inside_stable_versioned =
        try
          validate_module_version module_version type_decl.ptype_loc ;
          true
        with _ -> false
      in
      if inside_stable_versioned then
        Ppx_deriving.raise_errorf ~loc:type_decl.ptype_loc
          "Cannot use \"deriving bin_io_unversioned\" for a type defined in a \
           stable-versioned module"
  | _ ->
      ()

let rewrite_to_bin_io ~options ~path type_decls =
  let type_decl1 = List.hd_exn type_decls in
  let type_decl2 = List.last_exn type_decls in
  let loc =
    { loc_start= type_decl1.ptype_loc.loc_start
    ; loc_end= type_decl2.ptype_loc.loc_end
    ; loc_ghost= false }
  in
  if not (Int.equal (List.length type_decls) 1) then
    Ppx_deriving.raise_errorf ~loc
      "deriving bin_io_unversioned can only be used on a single type" ;
  if not @@ List.is_empty options then
    Ppx_deriving.raise_errorf ~loc
      "bin_io_unversioned does not take any options" ;
  let inner2_modules = List.take (List.rev path) 2 in
  validate_type_decl inner2_modules type_decl1 ;
  let ctxt =
    let derived_item_loc = Location.none in
    let omp_config =
      Migrate_parsetree.Driver.make_config ~debug:true
        ~tool_name:"ppxlib_driver" ()
    in
    let base = Expansion_context.Base.top_level ~omp_config ~file_path:"" in
    Expansion_context.Deriver.make ~derived_item_loc ~base ()
  in
  (* oops, gets a SEGV *)
  List.concat_map bin_io_gens ~f:(fun gen ->
      gen ~ctxt (Nonrecursive, type_decls) )

let () =
  Ppx_deriving.(register (create deriver ~type_decl_str:rewrite_to_bin_io ()))
