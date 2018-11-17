open! Stdune
open Import

module Var = struct
  type t =
    | Values of Value.t list
    | Project_root
    | First_dep
    | Deps
    | Targets
    | Named_local

  let to_sexp =
    let open Sexp.Encoder in
    function
    | Values values -> constr "Values" [list Value.to_sexp values]
    | Project_root -> string "Project_root"
    | First_dep -> string "First_dep"
    | Deps -> string "Deps"
    | Targets -> string "Targets"
    | Named_local -> string "Named_local"
end

module Macro = struct
  type t =
    | Exe
    | Dep
    | Bin
    | Lib
    | Libexec
    | Lib_available
    | Version
    | Read
    | Read_strings
    | Read_lines
    | Path_no_dep
    | Ocaml_config
    | Env

  let to_sexp =
    let open Sexp.Encoder in
    function
    | Exe -> string "Exe"
    | Dep -> string "Dep"
    | Bin -> string "Bin"
    | Lib -> string "Lib"
    | Libexec -> string "Libexec"
    | Lib_available -> string "Lib_available"
    | Version -> string "Version"
    | Read -> string "Read"
    | Read_strings -> string "Read_strings"
    | Read_lines -> string "Read_lines"
    | Path_no_dep -> string "Path_no_dep"
    | Ocaml_config -> string "Ocaml_config"
    | Env -> string "Env"
end

module Expansion = struct
  type t =
    | Var   of Var.t
    | Macro of Macro.t * string

  let to_sexp e =
    let open Sexp.Encoder in
    match e with
    | Var v -> pair string Var.to_sexp ("Var", v)
    | Macro (m, s) -> triple string Macro.to_sexp string ("Macro", m, s)
end

type 'a t =
  | No_info    of 'a
  | Since      of 'a * Syntax.Version.t
  | Deleted_in of 'a * Syntax.Version.t * string option
  | Renamed_in of Syntax.Version.t * string

let values v                       = No_info (Var.Values v)
let renamed_in ~new_name ~version  = Renamed_in (version, new_name)
let deleted_in ~version ?repl kind = Deleted_in (kind, version, repl)
let since ~version v               = Since (v, version)

type 'a pform = 'a t

module Map = struct
  type 'a map = 'a t String.Map.t

  type t =
    { vars   : Var.t   map
    ; macros : Macro.t map
    }

  let static_vars =
    String.Map.of_list_exn
      [ "targets", since ~version:(1, 0) Var.Targets
      ; "deps", since ~version:(1, 0) Var.Deps
      ; "project_root", since ~version:(1, 0) Var.Project_root

      ; "<", deleted_in Var.First_dep ~version:(1, 0)
               ~repl:"Use a named dependency instead:\
                      \n\
                      \n  (deps (:x <dep>) ...)\
                      \n   ... %{x} ..."
      ; "@", renamed_in ~version:(1, 0) ~new_name:"targets"
      ; "^", renamed_in ~version:(1, 0) ~new_name:"deps"
      ; "SCOPE_ROOT", renamed_in ~version:(1, 0) ~new_name:"project_root"
      ]

  let macros =
    let macro (x : Macro.t) = No_info x in
    String.Map.of_list_exn
      [ "exe", macro Exe
      ; "bin", macro Bin
      ; "lib", macro Lib
      ; "libexec", macro Libexec
      ; "lib-available", macro Lib_available
      ; "version", macro Version
      ; "read", macro Read
      ; "read-lines", macro Read_lines
      ; "read-strings", macro Read_strings

      ; "dep", since ~version:(1, 0) Macro.Dep

      ; "path", renamed_in ~version:(1, 0) ~new_name:"dep"
      ; "findlib", renamed_in ~version:(1, 0) ~new_name:"lib"

      ; "path-no-dep", deleted_in ~version:(1, 0) Macro.Path_no_dep
      ; "ocaml-config", macro Ocaml_config
      ; "env", since ~version:(1, 4) Macro.Env
      ]

  let create ~(context : Context.t) ~cxx_flags =
    let ocamlopt =
      match context.ocamlopt with
      | None -> Path.relative context.ocaml_bin "ocamlopt"
      | Some p -> p
    in
    let string s = values [Value.String s] in
    let path p = values [Value.Path p] in
    let make =
      match Bin.make ~path:(Env.path context.env) with
      | None   -> string "make"
      | Some p -> path p
    in
    let cflags = context.ocamlc_cflags in
    let strings s = values (Value.L.strings s) in
    let lowercased =
      [ "cpp"            , strings (context.c_compiler :: cflags @ ["-E"])
      ; "pa_cpp"         , strings (context.c_compiler :: cflags
                                    @ ["-undef"; "-traditional";
                                       "-x"; "c"; "-E"])
      ; "cc"             , strings (context.c_compiler :: cflags)
      ; "cxx"            , strings (context.c_compiler :: cxx_flags)
      ; "ocaml"          , path context.ocaml
      ; "ocamlc"         , path context.ocamlc
      ; "ocamlopt"       , path ocamlopt
      ; "arch_sixtyfour" , string (string_of_bool context.arch_sixtyfour)
      ; "make"           , make
      ]
    in
    let uppercased =
      List.map lowercased ~f:(fun (k, _) ->
        (String.uppercase k, renamed_in ~new_name:k ~version:(1, 0)))
    in
    let other =
      [ "-verbose"       , values []
      ; "ocaml_bin"      , values [Dir context.ocaml_bin]
      ; "ocaml_version"  , string context.version_string
      ; "ocaml_where"    , string (Path.to_string context.stdlib_dir)
      ; "null"           , string (Path.to_string Config.dev_null)
      ; "ext_obj"        , string context.ext_obj
      ; "ext_asm"        , string context.ext_asm
      ; "ext_lib"        , string context.ext_lib
      ; "ext_dll"        , string context.ext_dll
      ; "ext_exe"        , string context.ext_exe
      ; "profile"        , string context.profile
      ; "workspace_root" , values [Value.Dir context.build_dir]
      ; "context_name"   , string (Context.name context)
      ; "ROOT"           , renamed_in ~version:(1, 0) ~new_name:"workspace_root"
      ]
    in
    { vars =
        String.Map.superpose
          static_vars
          (String.Map.of_list_exn
             (List.concat
                [ lowercased
                ; uppercased
                ; other
                ]))
    ; macros
    }

  let superpose a b =
    { vars   = String.Map.superpose a.vars b.vars
    ; macros = String.Map.superpose a.macros b.macros
    }

  let rec expand map ~syntax_version ~pform =
    let open Option.O in
    let open Syntax.Version.Infix in
    let name = String_with_vars.Var.name pform in
    String.Map.find map name >>= fun v ->
    let describe = String_with_vars.Var.describe in
    match v with
    | No_info v -> Some v
    | Since (v, min_version) ->
      if syntax_version >= min_version then
        Some v
      else
        Syntax.Error.since (String_with_vars.Var.loc pform)
          Stanza.syntax min_version
          ~what:(describe pform)
    | Renamed_in (in_version, new_name) -> begin
        if syntax_version >= in_version then
          Syntax.Error.renamed_in (String_with_vars.Var.loc pform)
            Stanza.syntax syntax_version
            ~what:(describe pform)
            ~to_:(describe
                    (String_with_vars.Var.with_name pform ~name:new_name))
        else
          expand map ~syntax_version:in_version
            ~pform:(String_with_vars.Var.with_name pform ~name:new_name)
      end
    | Deleted_in (v, in_version, repl) ->
      if syntax_version < in_version then
        Some v
      else
        Syntax.Error.deleted_in (String_with_vars.Var.loc pform)
          Stanza.syntax in_version ~what:(describe pform) ?repl

  let expand t pform syntax_version =
    match String_with_vars.Var.payload pform with
    | None ->
      Option.map (expand t.vars ~syntax_version ~pform) ~f:(fun x ->
        Expansion.Var x)
    | Some payload ->
      Option.map (expand t.macros ~syntax_version ~pform) ~f:(fun x ->
        Expansion.Macro (x, payload))

  let empty =
    { vars   = String.Map.empty
    ; macros = String.Map.empty
    }

  let singleton k v =
    { vars   = String.Map.singleton k (No_info v)
    ; macros = String.Map.empty
    }

  let of_list_exn pforms =
    { vars = List.map ~f:(fun (k, x) -> (k, No_info x)) pforms
             |> String.Map.of_list_exn
    ; macros = String.Map.empty
    }

  let of_bindings bindings =
    { vars =
        Bindings.fold bindings ~init:String.Map.empty ~f:(fun x acc ->
          match x with
          | Unnamed _ -> acc
          | Named (s, _) -> String.Map.add acc s (No_info Var.Named_local))
    ; macros = String.Map.empty
    }

  let input_file path =
    let value = Var.Values (Value.L.paths [path]) in
    { vars =
        String.Map.of_list_exn
          [ "input-file", since ~version:(1, 0) value
          ; "<", renamed_in ~new_name:"input-file" ~version:(1, 0)
          ]
    ; macros = String.Map.empty
    }

  type stamp =
    (string * Var.t pform) list
    * (string * Macro.t pform) list

  let to_stamp { vars; macros } : stamp =
    ( String.Map.to_list vars
    , String.Map.to_list macros
    )
end
