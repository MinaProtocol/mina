open! Stdune
open Import
open Build.O
open! No_io

module SC = Super_context

module Preprocess = struct
  type t =
    | Pps of Dune_file.Preprocess.pps
    | Other

  let make : Dune_file.Preprocess.t -> t = function
    | Pps pps -> Pps pps
    | _       -> Other

  let merge a b =
    match a, b with
    | Other, Other -> Other
    | Pps _, Other -> a
    | Other, Pps _ -> b
    | Pps { loc = _; pps = pps1; flags = flags1; staged = s1 },
      Pps { loc = _; pps = pps2; flags = flags2; staged = s2 } ->
      match
        match Bool.compare s1 s2 with
        | Gt| Lt as ne -> ne
        | Eq ->
          match List.compare flags1 flags2 ~compare:String.compare with
          | Gt | Lt as ne -> ne
          | Eq ->
            List.compare pps1 pps2 ~compare:(fun (_, a) (_, b) ->
              Lib_name.compare a b)
      with
      | Eq -> a
      | _  -> Other
end

module Dot_file = struct
  let b = Buffer.create 256

  let printf = Printf.bprintf b
  let print = Buffer.add_string b

  let to_string ~obj_dirs ~src_dirs ~flags ~ppx ~remaindir =
    let serialize_path = Path.reach ~from:remaindir in
    Buffer.clear b;
    Path.Set.iter obj_dirs ~f:(fun p ->
      printf "B %s\n" (serialize_path p));
    Path.Set.iter src_dirs ~f:(fun p ->
      printf "S %s\n" (serialize_path p));
    begin match ppx with
    | [] -> ()
    | ppx ->
      printf "FLG -ppx %s\n"
        (List.map ppx ~f:quote_for_shell
         |> String.concat ~sep:" "
         |> Filename.quote)
    end;
    begin match flags with
    | [] -> ()
    | flags ->
      print "FLG";
      List.iter flags ~f:(fun f -> printf " %s" (quote_for_shell f));
      print "\n"
    end;
    Buffer.contents b
end

type t =
  { requires   : Lib.Set.t
  ; flags      : (unit, string list) Build.t
  ; preprocess : Preprocess.t
  ; libname    : Lib_name.Local.t option
  ; source_dirs: Path.Set.t
  ; objs_dirs  : Path.Set.t
  }

let make
      ?(requires=Ok [])
      ?(flags=Build.return [])
      ?(preprocess=Dune_file.Preprocess.No_preprocessing)
      ?libname
      ?(source_dirs=Path.Set.empty)
      ?(objs_dirs=Path.Set.empty)
      () =
  (* Merlin shouldn't cause the build to fail, so we just ignore errors *)
  let requires =
    match requires with
    | Ok    l -> Lib.Set.of_list l
    | Error _ -> Lib.Set.empty
  in
  { requires
  ; flags      = Build.catch flags    ~on_error:(fun _ -> [])
  ; preprocess = Preprocess.make preprocess
  ; libname
  ; source_dirs
  ; objs_dirs
  }

let add_source_dir t dir =
  { t with source_dirs = Path.Set.add t.source_dirs dir }

let ppx_flags sctx ~dir:_ ~scope ~dir_kind { preprocess; libname; _ } =
  match preprocess with
  | Pps { loc = _; pps; flags; staged = _ } -> begin
    match Preprocessing.get_ppx_driver sctx ~scope ~dir_kind pps with
    | Ok exe ->
      (Path.to_absolute_filename exe
       :: "--as-ppx"
       :: Preprocessing.cookie_library_name libname
       @ flags)
    | Error _ -> []
  end
  | Other -> []

let dot_merlin sctx ~dir ~more_src_dirs ~scope ~dir_kind
      ({ requires; flags; _ } as t) =
  match Path.drop_build_context dir with
  | None -> ()
  | Some remaindir ->
    let merlin_file = Path.relative dir ".merlin" in
    (* We make the compilation of .ml/.mli files depend on the
       existence of .merlin so that they are always generated, however
       the command themselves don't read the merlin file, so we don't
       want to declare a dependency on the contents of the .merlin
       file.

       Currently dune doesn't support declaring a dependency only
       on the existence of a file, so we have to use this trick. *)
    SC.add_rule sctx ~dir
      (Build.path merlin_file
       >>>
       Build.create_file (Path.relative dir ".merlin-exists"));
    Path.Set.singleton merlin_file
    |> SC.add_alias_deps sctx (Build_system.Alias.check ~dir);
    SC.add_rule sctx ~dir ~mode:Promote_but_delete_on_clean (
      flags
      >>^ (fun flags ->
        let (src_dirs, obj_dirs) =
          Lib.Set.fold requires ~init:(t.source_dirs, t.objs_dirs)
            ~f:(fun (lib : Lib.t) (src_dirs, obj_dirs) ->
              ( Path.Set.add src_dirs (
                  Lib.src_dir lib
                  |> Path.drop_optional_build_context)
              ,
              let obj_dirs = Path.Set.add obj_dirs (Lib.obj_dir lib) in
              match Lib.private_obj_dir lib with
              | None -> obj_dirs
              | Some private_obj_dir -> Path.Set.add obj_dirs private_obj_dir
            ))
        in
        let src_dirs =
          Path.Set.union src_dirs (Path.Set.of_list more_src_dirs)
        in
        Dot_file.to_string
          ~remaindir
          ~ppx:(ppx_flags sctx ~dir ~scope ~dir_kind t)
          ~flags
          ~src_dirs
          ~obj_dirs)
      >>>
      Build.write_file_dyn merlin_file)

let merge_two a b =
  { requires = Lib.Set.union a.requires b.requires
  ; flags = a.flags &&& b.flags >>^ (fun (a, b) -> a @ b)
  ; preprocess = Preprocess.merge a.preprocess b.preprocess
  ; libname =
      (match a.libname with
       | Some _ as x -> x
       | None -> b.libname)
  ; source_dirs = Path.Set.union a.source_dirs b.source_dirs
  ; objs_dirs = Path.Set.union a.objs_dirs b.objs_dirs
  }

let merge_all = function
  | [] -> None
  | init::ts -> Some (List.fold_left ~init ~f:merge_two ts)

let add_rules sctx ~dir ~more_src_dirs ~scope ~dir_kind merlin =
  if (SC.context sctx).merlin then
    dot_merlin sctx ~dir ~more_src_dirs ~scope ~dir_kind merlin
