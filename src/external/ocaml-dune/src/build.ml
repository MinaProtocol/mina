open! Stdune
open Import

module Vspec = struct
  type 'a t = T : Path.t * 'a Vfile_kind.t -> 'a t
end

module Repr = struct
  type ('a, 'b) t =
    | Arr : ('a -> 'b) -> ('a, 'b) t
    | Targets : Path.t list -> ('a, 'a) t
    | Store_vfile : 'a Vspec.t -> ('a, Action.t) t
    | Compose : ('a, 'b) t * ('b, 'c) t -> ('a, 'c) t
    | First : ('a, 'b) t -> ('a * 'c, 'b * 'c) t
    | Second : ('a, 'b) t -> ('c * 'a, 'c * 'b) t
    | Split : ('a, 'b) t * ('c, 'd) t -> ('a * 'c, 'b * 'd) t
    | Fanout : ('a, 'b) t * ('a, 'c) t -> ('a, 'b * 'c) t
    | Paths : Path.Set.t -> ('a, 'a) t
    | Paths_for_rule : Path.Set.t -> ('a, 'a) t
    | Paths_glob : glob_state ref -> ('a, Path.Set.t) t
    (* The reference gets decided in Build_interpret.deps *)
    | If_file_exists : Path.t * ('a, 'b) if_file_exists_state ref -> ('a, 'b) t
    | Contents : Path.t -> ('a, string) t
    | Lines_of : Path.t -> ('a, string list) t
    | Vpath : 'a Vspec.t -> (unit, 'a) t
    | Dyn_paths : ('a, Path.Set.t) t -> ('a, 'a) t
    | Record_lib_deps : Lib_deps_info.t -> ('a, 'a) t
    | Fail : fail -> (_, _) t
    | Memo : 'a memo -> (unit, 'a) t
    | Catch : ('a, 'b) t * (exn -> 'b) -> ('a, 'b) t
    | Lazy_no_targets : ('a, 'b) t Lazy.t -> ('a, 'b) t
    | Env_var : string -> ('a, 'a) t

  and 'a memo =
    { name          : string
    ; t             : (unit, 'a) t
    ; mutable state : 'a memo_state
    }

  and 'a memo_state =
    | Unevaluated
    | Evaluating
    | Evaluated of 'a * Deps.t

  and ('a, 'b) if_file_exists_state =
    | Undecided of ('a, 'b) t * ('a, 'b) t
    | Decided   of bool * ('a, 'b) t

  and glob_state =
    | G_unevaluated of Loc.t * Path.t * (Path.t -> bool)
    | G_evaluated   of Path.Set.t

  let get_if_file_exists_exn state =
    match !state with
    | Decided (_, t) -> t
    | Undecided _ ->
      Exn.code_error "Build.get_if_file_exists_exn: got undecided" []

  let get_glob_result_exn state =
    match !state with
    | G_evaluated l -> l
    | G_unevaluated (loc, path, _) ->
      Exn.code_error "Build.get_glob_result_exn: got unevaluated"
        [ "loc", Loc.to_sexp loc
        ; "path", Path.to_sexp path ]
end
include Repr
let repr t = t

let arr f = Arr f
let return x = Arr (fun () -> x)

let record_lib_deps lib_deps =
  Record_lib_deps lib_deps

module O = struct
  let ( >>> ) a b =
    match a, b with
    | Arr a, Arr b -> Arr (fun x -> (b (a x)))
    | _ -> Compose (a, b)

  let ( >>^ ) t f = t >>> arr f
  let ( ^>> ) f t = arr f >>> t

  let ( *** ) a b = Split (a, b)
  let ( &&& ) a b = Fanout (a, b)
end
open O

let first t = First t
let second t = Second t
let fanout a b = Fanout (a, b)
let fanout3 a b c =
  let open O in
  (a &&& (b &&& c))
  >>>
  arr (fun (a, (b, c)) -> (a, b, c))
let fanout4 a b c d =
  let open O in
  (a &&& (b &&& (c &&& d)))
  >>>
  arr (fun (a, (b, (c, d))) -> (a, b, c, d))

let rec all = function
  | [] -> arr (fun _ -> [])
  | t :: ts ->
    t &&& all ts
    >>>
    arr (fun (x, y) -> x :: y)

let lazy_no_targets t = Lazy_no_targets t

let path p = Paths (Path.Set.singleton p)
let paths ps = Paths (Path.Set.of_list ps)
let path_set ps = Paths ps
let paths_glob ~loc ~dir re =
  let predicate p = Re.execp re (Path.basename p) in
  Paths_glob (ref (G_unevaluated (loc, dir, predicate)))
let paths_matching ~loc ~dir f =
  Paths_glob (ref (G_unevaluated (loc, dir, f)))
let vpath vp = Vpath vp
let dyn_paths t = Dyn_paths (t >>^ Path.Set.of_list)
let dyn_path_set t = Dyn_paths t
let paths_for_rule ps = Paths_for_rule ps

let env_var s = Env_var s

let catch t ~on_error = Catch (t, on_error)

let contents p = Contents p
let lines_of p = Lines_of p

let strings p =
  lines_of p
  >>^ fun l ->
  List.map l ~f:Scanf.unescaped

let read_sexp p syntax =
  contents p
  >>^ fun s ->
  Dune_lang.parse_string s
    ~lexer:(Dune_lang.Lexer.of_syntax syntax)
    ~fname:(Path.to_string p) ~mode:Single

let if_file_exists p ~then_ ~else_ =
  If_file_exists (p, ref (Undecided (then_, else_)))

let file_exists p =
  if_file_exists p
    ~then_:(arr (fun _ -> true))
    ~else_:(arr (fun _ -> false))

let file_exists_opt p t =
  if_file_exists p
    ~then_:(t >>^ fun x -> Some x)
    ~else_:(arr (fun _ -> None))

let fail ?targets x =
  match targets with
  | None -> Fail x
  | Some l -> Targets l >>> Fail x

let of_result ?targets = function
  | Ok    x -> x
  | Error e -> fail ?targets { fail = fun () -> raise e }

let of_result_map ?targets res ~f =
  match res with
  | Ok    x -> f x
  | Error e -> fail ?targets { fail = fun () -> raise e }

let memoize name t =
  Memo { name; t; state = Unevaluated }

let source_tree ~dir ~file_tree =
  let prefix_with, dir =
    match Path.extract_build_context_dir dir with
    | None -> (Path.root, dir)
    | Some (ctx_dir, src_dir) -> (ctx_dir, src_dir)
  in
  let paths = File_tree.files_recursively_in file_tree dir ~prefix_with in
  path_set paths >>^ fun _ -> paths

let store_vfile spec = Store_vfile spec

let get_prog = function
  | Ok p -> path p >>> arr (fun _ -> Ok p)
  | Error f ->
    arr (fun _ -> Error f)
    >>> dyn_paths (arr (function Error _ -> [] | Ok x -> [x]))

let prog_and_args ?(dir=Path.root) prog args =
  Paths (Arg_spec.add_deps args Path.Set.empty)
  >>>
  (get_prog prog &&&
   (arr (Arg_spec.expand ~dir args)
    >>>
    dyn_path_set (arr (fun (_args, deps) -> deps))
    >>>
    arr fst))

let run ~dir ?stdout_to prog args =
  let targets = Arg_spec.add_targets args (Option.to_list stdout_to) in
  prog_and_args ~dir prog args
  >>>
  Targets targets
  >>^ (fun (prog, args) ->
    let action : Action.t = Run (prog, args) in
    let action =
      match stdout_to with
      | None      -> action
      | Some path -> Redirect (Stdout, path, action)
    in
    Action.Chdir (dir, action))

let action ?dir ~targets action =
  Targets targets
  >>^ fun _ ->
  match dir with
  | None -> action
  | Some dir -> Action.Chdir (dir, action)

let action_dyn ?dir ~targets () =
  Targets targets
  >>^ fun action ->
  match dir with
  | None -> action
  | Some dir -> Action.Chdir (dir, action)

let write_file fn s =
  action ~targets:[fn] (Write_file (fn, s))

let write_file_dyn fn =
  Targets [fn]
  >>^ fun s ->
  Action.Write_file (fn, s)

let copy ~src ~dst =
  path src >>>
  action ~targets:[dst] (Copy (src, dst))

let copy_and_add_line_directive ~src ~dst =
  path src >>>
  action ~targets:[dst]
    (Copy_and_add_line_directive (src, dst))

let symlink ~src ~dst =
  path src >>>
  action ~targets:[dst] (Symlink (src, dst))

let create_file fn =
  action ~targets:[fn] (Redirect (Stdout, fn, Progn []))

let remove_tree dir =
  arr (fun _ -> Action.Remove_tree dir)

let mkdir dir =
  arr (fun _ -> Action.Mkdir dir)

let progn ts =
  all ts >>^ fun actions ->
  Action.Progn actions

let merge_files_dyn ~target =
  dyn_paths (arr fst)
  >>^ (fun (sources, extras) ->
    Action.Merge_files_into (sources, extras, target))
  >>> action_dyn ~targets:[target] ()
