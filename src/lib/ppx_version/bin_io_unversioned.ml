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
     -> (string * expression) list
     -> structure_item list )
    list =
  List.map [ "bin_shape"; "bin_read"; "bin_write"; "bin_type_class" ]
    ~f:(fun name ->
      let deriver = Option.value_exn (Ppx_derivers.lookup name) in
      (* deriver is an instance of Ppxlib.Deriving.Deriver.deriver

         if instead we consider it to be an instance of Ppx_deriving.t,
           the 0th field, which should be the name, but prints out as garbage

         the 0th field of deriver is a string "Ppxlib__Deriving.Deriver.T",
           perhaps an artifact of the += type extension
         the 1st field of deriver appears to be of type
           Ppxlib.Deriving.Deriver.t, and the 0th field of that gives us
           an Actual_deriver.t

         the 0th field of the Actual_deriver.t should be the name, which
           prints out as expected

         the number of fields of the Actual_deriver.t is 8, which corresponds
           to the type definition

         from the Actual_deriver.t, we pull out the 1st field, the Generator.t
           with the label str_type_decl; we then apply the generator
      *)
      let actual_deriver =
        let constructor_argument_idx = 0 in
        let extension_constructor_argument_idx = 1 in
        Obj.(
          repr deriver
          (* Ppxlib.Deriving.Deriver.T x -> x *)
          |> (fun r -> field r extension_constructor_argument_idx)
          (* Ppxlib.Deriving.Deriver.Actual_deriver x -> x *)
          |> fun r -> field r constructor_argument_idx)
      in
      let name =
        (* Ppxlib.Deriving.Deriver.Actual_deriver.t, 0th field is name *)
        let name_idx = 0 in
        actual_deriver |> fun r -> Obj.(field r name_idx |> obj)
      in
      let generator :
          (structure, rec_flag * type_declaration list) Deriving.Generator.t =
        (* Ppxlib.Deriving.Deriver.Actual_deriver.t, 1st field is
             str_type_decl *)
        let str_type_decl_idx = 1 in
        Option.value_exn
          (actual_deriver |> fun r -> Obj.(field r str_type_decl_idx |> obj))
      in
      Deriving.Generator.apply ~name generator )

let validate_type_decl inner2_modules type_decl =
  match inner2_modules with
  | [ module_version; "Stable" ] ->
      let inside_stable_versioned =
        try
          validate_module_version module_version type_decl.ptype_loc ;
          true
        with _ -> false
      in
      if inside_stable_versioned then
        Location.raise_errorf ~loc:type_decl.ptype_loc
          "Cannot use \"deriving bin_io_unversioned\" for a type defined in a \
           stable-versioned module"
  | _ ->
      ()

let ctxt_base =
  Expansion_context.Base.top_level ~tool_name:"ppxlib_driver" ~file_path:""
    ~input_name:""

let rewrite_to_bin_io ~loc ~path (_rec_flag, type_decls) =
  let type_decl1 = List.hd_exn type_decls in
  if not (Int.equal (List.length type_decls) 1) then
    Location.raise_errorf ~loc
      "deriving bin_io_unversioned can only be used on a single type" ;
  let module_path = List.drop String.(split path ~on:'.') 2 in
  let inner2_modules = List.take (List.rev module_path) 2 in
  validate_type_decl inner2_modules type_decl1 ;
  let ctxt =
    let derived_item_loc = loc in
    (* TODO: is inline:false what we want? *)
    Expansion_context.Deriver.make ~derived_item_loc ~base:ctxt_base ()
      ~inline:false
  in
  List.concat_map bin_io_gens ~f:(fun gen ->
      gen ~ctxt (Nonrecursive, type_decls) [] )

let str_type_decl :
    (structure, rec_flag * type_declaration list) Ppxlib.Deriving.Generator.t =
  let open Ppxlib.Deriving in
  Generator.make_noarg rewrite_to_bin_io

let () = Ppxlib.Deriving.add deriver ~str_type_decl |> Ppxlib.Deriving.ignore
