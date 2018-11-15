open! Import

type t =
  { paths : Path.Set.t
  ; vars : String.Set.t
  }

let paths t = t.paths

let trace_path fn =
  (Path.to_string fn, Utils.Cached_digest.file fn)

let trace_var env var =
  let value =
    match Env.get env var with
    | None -> "unset"
    | Some v -> Digest.string v |> Digest.to_hex
  in
  (var, value)

let trace {paths; vars} env =
  List.concat
    [ List.map ~f:trace_path @@ Path.Set.to_list paths
    ; List.map ~f:(trace_var env) @@ String.Set.to_list vars
    ]

let union {paths = paths_a; vars = vars_a} {paths = paths_b; vars = vars_b} =
  { paths = Path.Set.union paths_a paths_b
  ; vars = String.Set.union vars_a vars_b
  }

let path_union a b =
  Path.Set.union a.paths b.paths

let path_diff a b =
  Path.Set.diff a.paths b.paths

let empty =
  { paths = Path.Set.empty
  ; vars = String.Set.empty
  }

let add_path t path =
  { t with
    paths = Path.Set.add t.paths path
  }

let add_paths t fns =
  { t with
    paths = Path.Set.union t.paths fns
  }

let add_env_var t var =
  { t with
    vars = String.Set.add t.vars var
  }

let to_sexp {paths; vars} =
  let sexp_paths =
    Dune_lang.Encoder.list Path_dune_lang.encode (Path.Set.to_list paths)
  in
  let sexp_vars =
    Dune_lang.Encoder.list Dune_lang.Encoder.string (String.Set.to_list vars)
  in
  Dune_lang.Encoder.record
    [ ("paths", sexp_paths)
    ; ("vars", sexp_vars)
    ]
