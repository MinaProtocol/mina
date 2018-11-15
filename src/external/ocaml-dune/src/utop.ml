open! Stdune
open Import
open Dune_file
open Build.O
open! No_io

let exe_name = "utop"
let main_module_name = Module.Name.of_string exe_name
let main_module_filename = exe_name ^ ".ml"

let pp_ml fmt include_dirs =
  let pp_include fmt =
    let pp_sep fmt () = Format.fprintf fmt "@ ; " in
    Format.pp_print_list ~pp_sep (fun fmt p ->
      Format.fprintf fmt "%S" (Path.to_absolute_filename p)
    ) fmt
  in
  Format.fprintf fmt "@[<v 2>Clflags.include_dirs :=@ [ %a@ ]@];@."
    pp_include include_dirs;
  Format.fprintf fmt "@.UTop_main.main ();@."

let add_module_rules sctx ~dir lib_requires =
  let path = Path.relative dir main_module_filename in
  let utop_ml =
    Build.of_result_map lib_requires ~f:(fun libs ->
      Build.arr (fun () ->
        let include_paths =
          let ctx = Super_context.context sctx in
          Path.Set.to_list
            (Lib.L.include_paths libs ~stdlib_dir:ctx.stdlib_dir)
        in
        let b = Buffer.create 64 in
        let fmt = Format.formatter_of_buffer b in
        pp_ml fmt include_paths;
        Format.pp_print_flush fmt ();
        Buffer.contents b))
    >>> Build.write_file_dyn path
  in
  Super_context.add_rule sctx ~dir utop_ml

let utop_dir_basename = ".utop"

let utop_exe_dir ~dir = Path.relative dir utop_dir_basename

let utop_exe =
  (* Use the [.exe] version. As the utop executable is declared with
     [(modes (byte))], the [.exe] correspond the bytecode linked in
     custom mode. We do that so that it works without hassle when
     generating a utop for a library with C stubs. *)
  Filename.concat utop_dir_basename (exe_name ^ Mode.exe_ext Mode.Native)

let is_utop_dir dir = Path.basename dir = utop_dir_basename

let libs_under_dir sctx ~db ~dir =
  let open Option.O in
  (Path.drop_build_context dir >>= fun dir ->
   File_tree.find_dir (Super_context.file_tree sctx) dir >>|
   (File_tree.Dir.fold ~traverse_ignored_dirs:true
      ~init:[] ~f:(fun dir acc ->
        let dir =
          Path.append (Super_context.build_dir sctx) (File_tree.Dir.path dir) in
        match Super_context.stanzas_in sctx ~dir with
        | None -> acc
        | Some (d : Super_context.Dir_with_dune.t) ->
          List.fold_left d.stanzas ~init:acc ~f:(fun acc -> function
            | Dune_file.Library l ->
              begin match Lib.DB.find_even_when_hidden db
                            (Library.best_name l) with
              | None -> acc (* library is defined but outside our scope *)
              | Some lib ->
                (* still need to make sure that it's not coming from an external
                   source *)
                if Path.is_descendant ~of_:dir (Lib.src_dir lib) then
                  lib :: acc
                else
                  acc (* external lib with a name matching our private name *)
              end
            | _ ->
              acc))))
  |> Option.value ~default:[]

let setup sctx ~dir =
  let scope = Super_context.find_scope_by_dir sctx dir in
  let utop_exe_dir = utop_exe_dir ~dir in
  let db = Scope.libs scope in
  let libs = libs_under_dir sctx ~db ~dir in
  let modules =
    Module.Name.Map.singleton
      main_module_name
      (Module.make main_module_name
         ~visibility:Public
         ~impl:{ path   = Path.relative utop_exe_dir main_module_filename
               ; syntax = Module.Syntax.OCaml
               }
         ~obj_name:exe_name)
  in
  let loc = Loc.in_dir (Path.to_string dir) in
  let requires =
    let open Result.O in
    (loc, Lib_name.of_string_exn ~loc:(Some loc) "utop")
    |> Lib.DB.resolve db >>| (fun utop -> utop :: libs)
    >>= Lib.closure ~linking:true
  in
  let cctx =
    Compilation_context.create ()
      ~super_context:sctx
      ~scope
      ~dir:utop_exe_dir
      ~modules
      ~opaque:false
      ~requires
      ~flags:(Ocaml_flags.append_common
                (Ocaml_flags.default ~profile:(Super_context.profile sctx))
                ["-w"; "-24"])
  in
  Exe.build_and_link cctx
    ~program:{ name = exe_name ; main_module_name ; loc }
    ~linkages:[Exe.Linkage.custom]
    ~link_flags:(Build.return ["-linkall"; "-warn-error"; "-31"]);
  add_module_rules sctx ~dir:utop_exe_dir requires
