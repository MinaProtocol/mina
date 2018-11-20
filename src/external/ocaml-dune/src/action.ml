open! Stdune
open Import

module Outputs = Action_ast.Outputs
module Diff_mode = Action_ast.Diff_mode

module Make_mapper
    (Src : Action_intf.Ast)
    (Dst : Action_intf.Ast)
= struct
  let map_one_step f (t : Src.t) ~dir ~f_program ~f_string ~f_path : Dst.t =
    match t with
    | Run (prog, args) ->
      Run (f_program ~dir prog, List.map args ~f:(f_string ~dir))
    | Chdir (fn, t) ->
      Chdir (f_path ~dir fn, f t ~dir:fn ~f_program ~f_string ~f_path)
    | Setenv (var, value, t) ->
      Setenv (f_string ~dir var, f_string ~dir value, f t ~dir ~f_program ~f_string ~f_path)
    | Redirect (outputs, fn, t) ->
      Redirect (outputs, f_path ~dir fn, f t ~dir ~f_program ~f_string ~f_path)
    | Ignore (outputs, t) ->
      Ignore (outputs, f t ~dir ~f_program ~f_string ~f_path)
    | Progn l -> Progn (List.map l ~f:(fun t -> f t ~dir ~f_program ~f_string ~f_path))
    | Echo xs -> Echo (List.map xs ~f:(f_string ~dir))
    | Cat x -> Cat (f_path ~dir x)
    | Copy (x, y) -> Copy (f_path ~dir x, f_path ~dir y)
    | Symlink (x, y) ->
      Symlink (f_path ~dir x, f_path ~dir y)
    | Copy_and_add_line_directive (x, y) ->
      Copy_and_add_line_directive (f_path ~dir x, f_path ~dir y)
    | System x -> System (f_string ~dir x)
    | Bash x -> Bash (f_string ~dir x)
    | Write_file (x, y) -> Write_file (f_path ~dir x, f_string ~dir y)
    | Rename (x, y) -> Rename (f_path ~dir x, f_path ~dir y)
    | Remove_tree x -> Remove_tree (f_path ~dir x)
    | Mkdir x -> Mkdir (f_path ~dir x)
    | Digest_files x -> Digest_files (List.map x ~f:(f_path ~dir))
    | Diff { optional; file1; file2; mode } ->
      Diff { optional
           ; file1 = f_path ~dir file1
           ; file2 = f_path ~dir file2
           ; mode
           }
    | Merge_files_into (sources, extras, target) ->
      Merge_files_into
        (List.map sources ~f:(f_path ~dir),
         List.map extras ~f:(f_string ~dir),
         f_path ~dir target)

  let rec map t ~dir ~f_program ~f_string ~f_path =
    map_one_step map t ~dir ~f_program ~f_string ~f_path
end

module Prog = struct
  module Not_found = struct
    type t =
      { context : string
      ; program : string
      ; hint    : string option
      ; loc     : Loc.t option
      }

    let raise { context ; program ; hint ; loc } =
      Utils.program_not_found ?hint ~loc ~context program
  end

  type t = (Path.t, Not_found.t) result

  let decode : t Dune_lang.Decoder.t =
    Dune_lang.Decoder.map Path_dune_lang.decode ~f:Result.ok

  let encode = function
    | Ok s -> Path_dune_lang.encode s
    | Error (e : Not_found.t) -> Dune_lang.Encoder.string e.program
end

module type Ast = Action_intf.Ast
  with type program = Prog.t
  with type path    = Path.t
  with type string  = String.t
module rec Ast : Ast = Ast

module String_with_sexp = struct
  type t = string
  let decode = Dune_lang.Decoder.string
  let encode = Dune_lang.Encoder.string
end

include Action_ast.Make(Prog)(Path_dune_lang)(String_with_sexp)(Ast)
type program = Prog.t
type path = Path.t
type string = String.t

module For_shell = struct
  module type Ast = Action_intf.Ast
    with type program = string
    with type path    = string
    with type string  = string
  module rec Ast : Ast = Ast

  include Action_ast.Make
      (String_with_sexp)
      (String_with_sexp)
      (String_with_sexp)
      (Ast)
end

module Relativise = Make_mapper(Ast)(For_shell.Ast)

let for_shell t =
  let rec loop t ~dir ~f_program ~f_string ~f_path =
    match t with
    | Symlink (src, dst) ->
      let src =
        match Path.parent dst with
        | None -> Path.to_string src
        | Some from -> Path.reach ~from src
      in
      let dst = Path.reach ~from:dir dst in
      For_shell.Symlink (src, dst)
    | t ->
      Relativise.map_one_step loop t ~dir ~f_program ~f_string ~f_path
  in
  loop t
    ~dir:Path.root
    ~f_string:(fun ~dir:_ x -> x)
    ~f_path:(fun ~dir x -> Path.reach x ~from:dir)
    ~f_program:(fun ~dir x ->
      match x with
      | Ok p -> Path.reach p ~from:dir
      | Error e -> e.program)

module Unresolved = struct
  module Program = struct
    type t =
      | This   of Path.t
      | Search of Loc.t option * string

    let of_string ~dir ~loc s =
      if String.contains s '/' then
        This (Path.relative dir s)
      else
        Search (loc, s)
  end

  module type Uast = Action_intf.Ast
    with type program = Program.t
    with type path    = Path.t
    with type string  = String.t
  module rec Uast : Uast = Uast
  include Uast

  include Make_mapper(Uast)(Ast)

  let resolve t ~f =
    map t
      ~dir:Path.root
      ~f_path:(fun ~dir:_ x -> x)
      ~f_string:(fun ~dir:_ x -> x)
      ~f_program:(fun ~dir:_ -> function
        | This p -> Ok p
        | Search (loc, s) -> Ok (f loc s))
end

let fold_one_step t ~init:acc ~f =
  match t with
  | Chdir (_, t)
  | Setenv (_, _, t)
  | Redirect (_, _, t)
  | Ignore (_, t) -> f acc t
  | Progn l -> List.fold_left l ~init:acc ~f
  | Run _
  | Echo _
  | Cat _
  | Copy _
  | Symlink _
  | Copy_and_add_line_directive _
  | System _
  | Bash _
  | Write_file _
  | Rename _
  | Remove_tree _
  | Mkdir _
  | Digest_files _
  | Diff _
  | Merge_files_into _ -> acc

include Make_mapper(Ast)(Ast)

let chdirs =
  let rec loop acc t =
    let acc =
      match t with
      | Chdir (dir, _) -> Path.Set.add acc dir
      | _ -> acc
    in
    fold_one_step t ~init:acc ~f:loop
  in
  fun t -> loop Path.Set.empty t

let symlink_managed_paths sandboxed deps =
  let steps =
    Path.Set.fold (Deps.paths deps)
      ~init:[]
      ~f:(fun path acc ->
        if Path.is_managed path then
          Symlink (path, sandboxed path)::acc
        else
          acc
      )
  in
  Progn steps

let sandbox t ~sandboxed ~deps ~targets : t =
  Progn
    [ symlink_managed_paths sandboxed deps
    ; map t
        ~dir:Path.root
        ~f_string:(fun ~dir:_ x -> x)
        ~f_path:(fun ~dir:_ p -> sandboxed p)
        ~f_program:(fun ~dir:_ x -> Result.map x ~f:sandboxed)
    ; Progn (List.filter_map targets ~f:(fun path ->
        if Path.is_managed path then
          Some (Rename (sandboxed path, path))
        else
          None))
    ]
