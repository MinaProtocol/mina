open Stdune

type t =
  { dir                   : Path.t
  ; inherit_from          : t Lazy.t option
  ; scope                 : Scope.t
  ; config                : Dune_env.Stanza.t
  ; mutable file_bindings : string File_bindings.t option
  ; mutable ocaml_flags   : Ocaml_flags.t option
  ; mutable external_     : Env.t option
  ; mutable artifacts     : Artifacts.t option
  }

let scope t = t.scope

let make ~dir ~inherit_from ~scope ~config ~env =
  { dir
  ; inherit_from
  ; scope
  ; config
  ; ocaml_flags = None
  ; external_ = env
  ; artifacts = None
  ; file_bindings = None
  }

let file_bindings t ~profile ~expander =
  match t.file_bindings with
  | Some x -> x
  | None ->
    let file_bindings =
      match Dune_env.Stanza.find t.config ~profile with
      | None -> []
      | Some cfg ->
        File_bindings.map cfg.binaries ~f:(fun template ->
          Expander.expand expander ~mode:Single ~template
          |> Value.to_string ~dir:t.dir)
    in
    t.file_bindings <- Some file_bindings;
    file_bindings

let rec external_ t ~profile ~default =
  match t.external_ with
  | Some x -> x
  | None ->
    let default =
      match t.inherit_from with
      | None -> default
      | Some (lazy t) -> external_ t ~default ~profile
    in
    let (env, have_binaries) =
      match Dune_env.Stanza.find t.config ~profile with
      | None -> (default, false)
      | Some cfg ->
        ( Env.extend_env default cfg.env_vars
        , not (File_bindings.is_empty cfg.binaries)
        )
    in
    let env =
      if have_binaries then
        Env.cons_path env ~dir:(Utils.local_bin t.dir)
      else
        env
    in
    t.external_ <- Some env;
    env

let rec artifacts t ~profile ~default ~expander =
  match t.artifacts with
  | Some x -> x
  | None ->
    let default =
      match t.inherit_from with
      | None -> default
      | Some (lazy t) -> artifacts t ~default ~profile ~expander
    in
    let artifacts =
      file_bindings t ~profile ~expander
      |> Artifacts.add_binaries default ~dir:t.dir
    in
    t.artifacts <- Some artifacts;
    artifacts

let rec ocaml_flags t ~profile ~expander =
  match t.ocaml_flags with
  | Some x -> x
  | None ->
    let default =
      match t.inherit_from with
      | None -> Ocaml_flags.default ~profile
      | Some (lazy t) -> ocaml_flags t ~profile ~expander
    in
    let flags =
      match Dune_env.Stanza.find t.config ~profile with
      | None -> default
      | Some cfg ->
        let expander = Expander.set_dir expander ~dir:t.dir in
        Ocaml_flags.make
          ~flags:cfg.flags
          ~ocamlc_flags:cfg.ocamlc_flags
          ~ocamlopt_flags:cfg.ocamlopt_flags
          ~default
          ~eval:(Expander.expand_and_eval_set expander)
    in
    t.ocaml_flags <- Some flags;
    flags
