open! Stdune
open Import
open Build.O
open Dune_file

module SC = Super_context

(* Encoded representation of a set of library names *)
module Key : sig
  val encode
    :  dir_kind:Dune_lang.Syntax.t
    -> Lib.t list
    -> Digest.t

  (* [decode s] fails if there hasn't been a previous call to [encode]
     such that [encode ~dir_kind l = s]. *)
  val decode : Digest.t -> Lib.t list
end = struct

  let reverse_table = Hashtbl.create 128
  let () = Hooks.End_of_build.always (fun () -> Hashtbl.reset reverse_table)

  let encode ~dir_kind libs =
    let libs =
      let compare a b = Lib_name.compare (Lib.name a) (Lib.name b) in
      match (dir_kind : Dune_lang.Syntax.t) with
      | Dune -> List.sort libs ~compare
      | Jbuild ->
        match List.rev libs with
        | last :: others -> List.sort others ~compare @ [last]
        | [] -> []
    in
    let scope_for_key =
      List.fold_left libs ~init:None ~f:(fun acc lib ->
        let scope_for_key =
          match Lib.status lib with
          | Private scope_name   -> Some scope_name
          | Public _ | Installed -> None
        in
        let open Dune_project.Name.Infix in
        match acc, scope_for_key with
        | Some a, Some b -> assert (a = b); acc
        | Some _, None   -> acc
        | None  , Some _ -> scope_for_key
      | None  , None   -> None)
    in
    let scope_key =
      match scope_for_key with
      | None -> ""
      | Some name ->
        match Dune_project.Name.to_encoded_string name with
        | "" -> assert false
        | s -> s
    in
    let key =
      (scope_key
       :: List.map libs ~f:(fun lib -> Lib.name lib |> Lib_name.to_string))
      |> String.concat ~sep:"\000"
      |> Digest.string
    in
    begin
      match Hashtbl.find reverse_table key with
      | None ->
        Hashtbl.add reverse_table key libs
      | Some libs' ->
        match List.compare libs libs' ~compare:(fun a b ->
          Int.compare (Lib.unique_id a) (Lib.unique_id b)) with
        | Eq -> ()
        | _ ->
          let string_of_libs libs =
            String.concat ~sep:", " (List.map libs ~f:(fun lib ->
              Lib_name.to_string (Lib.name lib)))
          in
          die "Hash collision between set of ppx drivers:\n\
               - %s\n\
               - %s"
            (string_of_libs libs)
            (string_of_libs libs')
    end;
    key

  let decode key =
    match Hashtbl.find reverse_table key with
    | Some libs -> libs
    | None ->
      die "I don't know what ppx rewriters set %s correspond to."
        (Digest.to_hex key)
end

let pped_path path ~suffix =
  (* We need to insert the suffix before the extension as some tools
     inspect the extension *)
  let base, ext = Path.split_extension path in
  Path.extend_basename base ~suffix:(suffix ^ ext)

let pped_module m ~f =
  Module.map_files m ~f:(fun kind file ->
    let pp_path = pped_path file.path ~suffix:".pp" in
    f kind file.path pp_path;
    { file with path = pp_path })

module Driver = struct
  module M = struct
    module Info = struct
      let name = Sub_system_name.make "ppx.driver"
      type t =
        { loc          : Loc.t
        ; flags        : Ordered_set_lang.Unexpanded.t
        ; as_ppx_flags : Ordered_set_lang.Unexpanded.t
        ; lint_flags   : Ordered_set_lang.Unexpanded.t
        ; main         : string
        ; replaces     : (Loc.t * Lib_name.t) list
        }

      type Dune_file.Sub_system_info.t += T of t

      let loc t = t.loc

      (* The syntax of the driver sub-system is part of the main dune
         syntax, so we simply don't create a new one.

         If we wanted to make the ppx system an extension, then we
         would create a new one.
      *)
      let syntax = Stanza.syntax

      open Stanza.Decoder

      let parse =
        record
          (let%map loc = loc
           and flags = Ordered_set_lang.Unexpanded.field "flags"
           and as_ppx_flags =
             Ordered_set_lang.Unexpanded.field "as_ppx_flags"
               ~check:(Syntax.since syntax (1, 2))
               ~default:(Ordered_set_lang.Unexpanded.of_strings ["--as-ppx"]
                           ~pos:__POS__)
           and lint_flags = Ordered_set_lang.Unexpanded.field "lint_flags"
           and main = field "main" string
           and replaces =
             field "replaces" (list (located (Lib_name.decode))) ~default:[]
           in
           { loc
           ; flags
           ; as_ppx_flags
           ; lint_flags
           ; main
           ; replaces
           })
    end

    (* The [lib] field is lazy so that we don't need to fill it for
       hardcoded [t] values used to implement the jbuild style
       handling of drivers.

       See [Jbuild_driver] below for details. *)
    type t =
      { info     : Info.t
      ; lib      : Lib.t Lazy.t
      ; replaces : t list Or_exn.t
      }

    let desc ~plural = "ppx driver" ^ if plural then "s" else ""
    let desc_article = "a"

    let lib      t = Lazy.force t.lib
    let replaces t = t.replaces

    let instantiate ~resolve ~get lib (info : Info.t) =
      { info
      ; lib = lazy lib
      ; replaces =
          let open Result.O in
          Result.List.map info.replaces ~f:(fun ((loc, name) as x) ->
            resolve x >>= fun lib ->
            match get ~loc lib with
            | None ->
              Error (Errors.exnf loc "%a is not a %s"
                       Lib_name.pp_quoted name
                       (desc ~plural:false))
            | Some t -> Ok t)
      }

    let encode t =
      let open Dune_lang.Encoder in
      let f x = Lib_name.encode (Lib.name (Lazy.force x.lib)) in
      ((1, 0),
       record
         [ "flags"            , Ordered_set_lang.Unexpanded.encode
                                  t.info.flags
         ; "lint_flags"       , Ordered_set_lang.Unexpanded.encode
                                  t.info.lint_flags
         ; "main"             , string t.info.main
         ; "replaces"         , list f (Result.ok_exn t.replaces)
         ])
  end
  include M
  include Sub_system.Register_backend(M)

  (* Where are we called from? *)
  type loc =
    | User_file of Loc.t * (Loc.t * Lib_name.t) list
    | Dot_ppx   of Path.t * Lib_name.t list

  let make_error loc msg =
    match loc with
    | User_file (loc, _) -> Error (Errors.exnf loc "%a" Fmt.text msg)
    | Dot_ppx (path, pps) ->
      Error (Errors.exnf (Loc.in_file (Path.to_string path)) "%a" Fmt.text
               (sprintf
                  "Failed to create on-demand ppx rewriter for %s; %s"
                  (String.enumerate_and (List.map pps ~f:Lib_name.to_string))
                  (String.uncapitalize msg)))

  let select libs ~loc =
    match select_replaceable_backend libs ~replaces with
    | Ok _ as x -> x
    | Error No_backend_found ->
      let msg =
        match libs with
        | [] ->
          "You must specify at least one ppx rewriter."
        | _ ->
          match
            List.filter_map libs ~f:(fun lib ->
              match Lib_name.to_string (Lib.name lib) with
              | "ocaml-migrate-parsetree" | "ppxlib" | "ppx_driver" as s ->
                Some s
              | _ -> None)
          with
          | [] ->
            let pps =
              match loc with
              | User_file (_, pps) -> List.map pps ~f:snd
              | Dot_ppx (_, pps) -> pps
            in
            sprintf
              "No ppx driver were found. It seems that %s %s not \
               compatible with Dune. Examples of ppx rewriters that \
               are compatible with Dune are ones using \
               ocaml-migrate-parsetree, ppxlib or ppx_driver."
              (String.enumerate_and (List.map pps ~f:Lib_name.to_string))
              (match pps with
               | [_] -> "is"
               | _   -> "are")
          | names ->
            sprintf
              "No ppx driver were found.\n\
               Hint: Try upgrading or reinstalling %s."
              (String.enumerate_and names)
      in
      make_error loc msg
    | Error (Too_many_backends ts) ->
      make_error loc
        (sprintf
           "Too many incompatible ppx drivers were found: %s."
           (String.enumerate_and (List.map ts ~f:(fun t ->
              Lib_name.to_string (Lib.name (lib t))))))
    | Error (Other exn) ->
      Error exn
end

module Jbuild_driver = struct
  (* This module is used to implement the jbuild handling of ppx
     drivers.  It doesn't implement exactly the same algorithm, but it
     should be enough for all jbuilder packages out there.

     It works as follow: given the list of ppx rewriters specified by
     the user, check whether the last one is named [ppxlib.runner] or
     [ppx_driver.runner]. If it isn't, assume the driver is
     ocaml-migrate-parsetree and use some hard-coded driver
     information. If it is, use the corresponding hardcoded driver
     information. *)

  let make name info : (Lib_name.t * Driver.t) Lazy.t = lazy (
    let info =
      let parsing_context =
        Univ_map.singleton (Syntax.key Stanza.syntax) (0, 0)
      in
      let fname = Printf.sprintf "<internal-%s>" name in
      Dune_lang.parse_string ~mode:Single ~fname info
        ~lexer:Dune_lang.Lexer.jbuild_token
      |> Dune_lang.Decoder.parse Driver.Info.parse parsing_context
    in
    (Lib_name.of_string_exn ~loc:None name,
     { info
     ; lib = lazy (assert false)
     ; replaces = Ok []
     }))
  let omp = make "ocaml-migrate-parsetree" {|
    ((main       Migrate_parsetree.Driver.run_main)
     (flags      (--dump-ast))
     (lint_flags (--null)))
  |}
  let ppxlib = make "ppxlib" {|
    ((main       Ppxlib.Driver.standalone)
     (flags      (-diff-cmd - -dump-ast))
     (lint_flags (-diff-cmd - -null    )))
  |}
  let ppx_driver = make "ppx_driver" {|
    ((main       Ppx_driver.standalone)
     (flags      (-diff-cmd - -dump-ast))
     (lint_flags (-diff-cmd - -null    )))
  |}

  let drivers =
    [ Lib_name.of_string_exn ~loc:None "ocaml-migrate-parsetree.driver-main" , omp
    ; Lib_name.of_string_exn ~loc:None "ppxlib.runner"                       , ppxlib
    ; Lib_name.of_string_exn ~loc:None "ppx_driver.runner"                   , ppx_driver
    ]

  let get_driver pps =
    let driver =
      match List.last pps with
      | None -> omp
      | Some (_, pp) -> Option.value (List.assoc drivers pp) ~default:omp
    in
    snd (Lazy.force driver)

  (* For building the driver *)
  let analyse_pps pps ~get_name =
    let driver, rev_others =
      match List.rev pps with
      | [] -> (omp, [])
      | pp :: rev_rest as rev_pps ->
        match List.assoc drivers (get_name pp) with
        | None        -> (omp   , rev_pps )
        | Some driver -> (driver, rev_rest)
    in
    let driver_name, driver = Lazy.force driver in
    (driver, driver_name, rev_others)
end

let ppx_exe sctx ~key ~dir_kind =
  match (dir_kind : Dune_lang.Syntax.t) with
  | Dune ->
    Path.relative (SC.build_dir sctx) (".ppx/" ^ key ^ "/ppx.exe")
  | Jbuild ->
    Path.relative (SC.build_dir sctx) (".ppx/jbuild/" ^ key ^ "/ppx.exe")

let build_ppx_driver sctx ~dep_kind ~target ~dir_kind ~pps ~pp_names =
  let ctx = SC.context sctx in
  let mode = Context.best_mode ctx in
  let compiler = Option.value_exn (Context.compiler ctx mode) in
  let jbuild_driver, pps, pp_names =
    match (dir_kind : Dune_lang.Syntax.t) with
    | Dune -> (None, pps, pp_names)
    | Jbuild ->
      match pps with
      | Error _ ->
        let driver, driver_name, pp_names =
          Jbuild_driver.analyse_pps pp_names ~get_name:(fun x -> x)
        in
        (Some driver, pps, driver_name :: pp_names)
      | Ok pps ->
        let driver, driver_name, pps =
          Jbuild_driver.analyse_pps pps ~get_name:Lib.name
        in
        let pp_names = driver_name :: List.map pps ~f:Lib.name in
        let pps =
          let open Result.O in
          Lib.DB.resolve_pps (SC.public_libs sctx) [(Loc.none, driver_name)]
          >>| fun driver ->
          driver @ pps
        in
        (Some driver, pps, pp_names)
  in
  let driver_and_libs =
    let open Result.O in
    Result.map_error ~f:(fun e ->
      (* Extend the dependency stack as we don't have locations at
         this point *)
      Dep_path.prepend_exn e (Preprocess pp_names))
      (pps
       >>= Lib.closure ~linking:true
       >>= fun pps ->
       match jbuild_driver with
       | None ->
         Driver.select pps ~loc:(Dot_ppx (target, pp_names))
         >>| fun driver ->
         (driver, pps)
       | Some driver ->
         Ok (driver, pps))
  in
  (* CR-someday diml: what we should do is build the .cmx/.cmo once
     and for all at the point where the driver is defined. *)
  let ml = Path.relative (Option.value_exn (Path.parent target)) "ppx.ml" in
  let add_rule = SC.add_rule sctx ~dir:(Super_context.build_dir sctx) in
  add_rule
    (Build.of_result_map driver_and_libs ~f:(fun (driver, _) ->
       Build.return (sprintf "let () = %s ()\n" driver.info.main))
     >>>
     Build.write_file_dyn ml);
  add_rule
    (Build.record_lib_deps
       (Lib_deps.info ~kind:dep_kind (Lib_deps.of_pps pp_names))
     >>>
     Build.of_result_map driver_and_libs ~f:(fun (_, libs) ->
       Build.paths (Lib.L.archive_files libs ~mode))
     >>>
     Build.run (Ok compiler) ~dir:ctx.build_dir
       [ A "-o" ; Target target
       ; Arg_spec.of_result
           (Result.map driver_and_libs ~f:(fun (_driver, libs) ->
              Lib.L.compile_and_link_flags ~mode ~stdlib_dir:ctx.stdlib_dir
                ~compile:libs
                ~link:libs))
       ; Dep ml
       ])

let get_rules sctx key ~dir_kind =
  let exe = ppx_exe sctx ~key ~dir_kind in
  let pps, pp_names =
    match Digest.from_hex key with
    | key ->
      let pps = Key.decode key in
      (Ok pps, List.map pps ~f:Lib.name)
    | exception _ ->
      (* Still support the old scheme for backward compatibility *)
      let (key, lib_db) = SC.Scope_key.of_string sctx key in
      let names =
        match key with
        | "+none+" -> []
        | _ -> String.split key ~on:'+'
      in
      let names =
        match List.rev names with
        | [] -> []
        | driver :: rest -> List.sort rest ~compare:String.compare @ [driver]
      in
      let names = List.map names ~f:(Lib_name.of_string_exn ~loc:None) in
      let pps =
        Lib.DB.resolve_pps lib_db (List.map names ~f:(fun x -> (Loc.none, x)))
      in
      (pps, names)
  in
  build_ppx_driver sctx ~pps ~pp_names ~dep_kind:Required ~target:exe ~dir_kind

let gen_rules sctx components =
  match components with
  | [key] -> get_rules sctx key ~dir_kind:Dune
  | ["jbuild"; key] -> get_rules sctx key ~dir_kind:Jbuild
  | _ -> ()

let ppx_driver_exe sctx libs ~dir_kind =
  let key = Digest.to_hex (Key.encode ~dir_kind libs) in
  ppx_exe sctx ~key ~dir_kind

module Compat_ppx_exe_kind = struct
  type t =
    | Dune
    | Jbuild of string option
end

let get_compat_ppx_exe sctx ~name ~kind =
  let name = Lib_name.to_string name in
  match (kind : Compat_ppx_exe_kind.t) with
  | Dune ->
    ppx_exe sctx ~key:name ~dir_kind:Dune
  | Jbuild driver ->
    (* We know both [name] and [driver] are public libraries, so we
       don't add the scope key. *)
    let key =
      match driver with
      | None -> name
      | Some d -> sprintf "%s+%s" name d
    in
    ppx_exe sctx ~key ~dir_kind:Jbuild

let get_ppx_driver sctx ~loc ~scope ~dir_kind pps =
  let open Result.O in
  Lib.DB.resolve_pps (Scope.libs scope) pps
  >>= fun libs ->
  (match (dir_kind : Dune_lang.Syntax.t) with
   | Dune ->
     Lib.closure libs ~linking:true
     >>=
     Driver.select ~loc:(User_file (loc, pps))
   | Jbuild ->
     Ok (Jbuild_driver.get_driver pps))
  >>| fun driver ->
  (ppx_driver_exe (SC.host sctx) libs ~dir_kind, driver)

let target_var         = String_with_vars.virt_var __POS__ "targets"
let workspace_root_var = String_with_vars.virt_var __POS__ "workspace_root"

let cookie_library_name lib_name =
  match lib_name with
  | None -> []
  | Some name ->
    ["--cookie"; sprintf "library-name=%S" (Lib_name.Local.to_string name)]

(* Generate rules for the reason modules in [modules] and return a
   a new module with only OCaml sources *)
let setup_reason_rules sctx (m : Module.t) =
  let ctx = SC.context sctx in
  let refmt =
    SC.resolve_program sctx ~loc:None ~dir:ctx.build_dir
      "refmt" ~hint:"try: opam install reason" in
  let rule src target =
    Build.run ~dir:ctx.build_dir refmt
      [ A "--print"
      ; A "binary"
      ; Dep src
      ]
      ~stdout_to:target
  in
  Module.map_files m ~f:(fun _ f ->
    match f.syntax with
    | OCaml  -> f
    | Reason ->
      let path =
        let base, ext = Path.split_extension f.path in
        let suffix =
          match ext with
          | ".re"  -> ".re.ml"
          | ".rei" -> ".re.mli"
          | _     ->
            Errors.fail
              (Loc.in_file
                 (Path.to_string (Path.drop_build_context_exn f.path)))
              "Unknown file extension for reason source file: %S"
              ext
        in
        Path.extend_basename base ~suffix
      in
      let ml = Module.File.make OCaml path in
      SC.add_rule sctx ~dir:ctx.build_dir (rule f.path ml.path);
      ml)

let promote_correction fn build ~suffix =
  Build.progn
    [ build
    ; Build.return
        (Action.diff ~optional:true
           fn
           (Path.extend_basename fn ~suffix))
    ]

let lint_module sctx ~dir ~dep_kind ~lint ~lib_name ~scope ~dir_kind =
  Staged.stage (
    let alias = Build_system.Alias.lint ~dir in
    let add_alias fn build =
      SC.add_alias_action sctx alias build ~dir
        ~stamp:("lint", lib_name, fn)
    in
    let lint =
      Per_module.map lint ~f:(function
        | Preprocess.No_preprocessing ->
          (fun ~source:_ ~ast:_ -> ())
        | Action (loc, action) ->
          (fun ~source ~ast:_ ->
             let action = Action_unexpanded.Chdir
                            (workspace_root_var, action) in
             Module.iter source ~f:(fun _ (src : Module.File.t) ->
               let bindings = Pform.Map.input_file src.path in
               add_alias src.path ~loc:(Some loc)
                 (Build.path src.path
                  >>^ (fun _ -> Bindings.empty)
                  >>> SC.Action.run sctx
                        action
                        ~loc
                        ~dir
                        ~dep_kind
                        ~bindings
                        ~targets:(Static [])
                        ~targets_dir:dir
                        ~scope)))
        | Pps { loc; pps; flags; staged } ->
          if staged then
            Errors.fail loc
              "Staged ppx rewriters cannot be used as linters.";
          let args : _ Arg_spec.t =
            S [ As flags
              ; As (cookie_library_name lib_name)
              ]
          in
          let corrected_suffix = ".lint-corrected" in
          let driver_and_flags =
            let open Result.O in
            get_ppx_driver sctx ~loc ~scope ~dir_kind pps
            >>| fun (exe, driver) ->
            (exe,
             let bindings =
               Pform.Map.singleton "corrected-suffix"
                 (Values [String corrected_suffix])
             in
             Build.memoize "ppx flags"
               (SC.expand_and_eval_set sctx driver.info.lint_flags
                  ~scope
                  ~dir
                  ~bindings
                  ~standard:(Build.return [])))
          in
          (fun ~source ~ast ->
             Module.iter ast ~f:(fun kind src ->
               add_alias src.path
                 ~loc:None
                 (promote_correction ~suffix:corrected_suffix
                    (Option.value_exn (Module.file source kind))
                    (Build.of_result_map driver_and_flags ~f:(fun (exe, flags) ->
                       flags >>>
                       Build.run ~dir:(SC.context sctx).build_dir
                         (Ok exe)
                         [ args
                         ; Ml_kind.ppx_driver_flag kind
                         ; Dep src.path
                         ; Dyn (fun x -> As x)
                         ]))))))
    in
    fun ~(source : Module.t) ~ast ->
      Per_module.get lint (Module.name source) ~source ~ast)

type t = (Module.t -> lint:bool -> Module.t) Per_module.t

let dummy = Per_module.for_all (fun m ~lint:_ -> m)

let make sctx ~dir ~dep_kind ~lint ~preprocess
      ~preprocessor_deps ~lib_name ~scope ~dir_kind =
  let preprocessor_deps =
    Build.memoize "preprocessor deps" preprocessor_deps
  in
  let lint_module =
    Staged.unstage (lint_module sctx ~dir ~dep_kind ~lint ~lib_name ~scope
                      ~dir_kind)
  in
  Per_module.map preprocess ~f:(function
    | Preprocess.No_preprocessing ->
      (fun m ~lint ->
         let ast = setup_reason_rules sctx m in
         if lint then lint_module ~ast ~source:m;
         ast)
    | Action (loc, action) ->
      (fun m ~lint ->
         let ast =
           pped_module m ~f:(fun _kind src dst ->
             let bindings = Pform.Map.input_file src in
             SC.add_rule sctx ~loc ~dir
               (preprocessor_deps
                >>>
                Build.path src
                >>^ (fun _ -> Bindings.empty)
                >>>
                SC.Action.run sctx
                  (Redirect
                     (Stdout,
                      target_var,
                      Chdir (workspace_root_var,
                             action)))
                  ~loc
                  ~dir
                  ~dep_kind
                  ~bindings
                  ~targets:(Static [dst])
                  ~targets_dir:dir
                  ~scope))
           |> setup_reason_rules sctx in
         if lint then lint_module ~ast ~source:m;
         ast)
    | Pps { loc; pps; flags; staged } ->
      if not staged then begin
        let args : _ Arg_spec.t =
          S [ As flags
            ; As (cookie_library_name lib_name)
            ]
        in
        let corrected_suffix = ".ppx-corrected" in
        let driver_and_flags =
          let open Result.O in
          get_ppx_driver sctx ~loc ~scope ~dir_kind pps >>| fun (exe, driver) ->
          (exe,
           let bindings =
             Pform.Map.singleton "corrected-suffix"
               (Values [String corrected_suffix])
           in
           Build.memoize "ppx flags"
             (SC.expand_and_eval_set sctx driver.info.flags
                ~scope
                ~dir
                ~bindings
                ~standard:(Build.return ["--as-ppx"])))
        in
        (fun m ~lint ->
           let ast = setup_reason_rules sctx m in
           if lint then lint_module ~ast ~source:m;
           pped_module ast ~f:(fun kind src dst ->
             SC.add_rule sctx ~loc ~dir
               (promote_correction ~suffix:corrected_suffix
                  (Option.value_exn (Module.file m kind))
                  (preprocessor_deps >>^ ignore
                   >>>
                   Build.of_result_map driver_and_flags
                     ~targets:[dst]
                     ~f:(fun (exe, flags) ->
                       flags
                       >>>
                       Build.run ~dir:(SC.context sctx).build_dir
                         (Ok exe)
                         [ args
                         ; A "-o"; Target dst
                         ; Ml_kind.ppx_driver_flag kind; Dep src
                         ; Dyn (fun x -> As x)
                         ])))))
      end else begin
        let pp_flags = Build.of_result (
          let open Result.O in
          get_ppx_driver sctx ~loc ~scope ~dir_kind pps >>| fun (exe, driver) ->
          Build.memoize "ppx command"
            (Build.path exe
             >>>
             preprocessor_deps >>^ ignore
             >>>
             SC.expand_and_eval_set sctx driver.info.as_ppx_flags
               ~scope
               ~dir
               ~standard:(Build.return [])
             >>^ fun flags ->
             let command =
               List.map
                 (List.concat
                    [ [Path.reach exe ~from:(SC.context sctx).build_dir]
                    ; flags
                    ; cookie_library_name lib_name
                    ])
                 ~f:quote_for_shell
               |> String.concat ~sep:" "
             in
             ["-ppx"; command]))
        in
        let pp = Some pp_flags in
        (fun m ~lint ->
           let ast = setup_reason_rules sctx m in
           if lint then lint_module ~ast ~source:m;
           Module.set_pp ast pp)
      end)

let pp_modules t ?(lint=true) modules =
  Module.Name.Map.map modules ~f:(fun (m : Module.t) ->
    Per_module.get t (Module.name m) m ~lint)

let pp_module_as t ?(lint=true) name m =
  Per_module.get t name m ~lint

let get_ppx_driver sctx ~scope ~dir_kind pps =
  let open Result.O in
  Lib.DB.resolve_pps (Scope.libs scope) pps
  >>| fun libs ->
  let sctx = SC.host sctx in
  ppx_driver_exe sctx libs ~dir_kind
