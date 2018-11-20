open! Stdune

module File = struct
  type t =
    { src : Path.t
    ; dst : Path.t
    }

  (* XXX these sexp converters will be useful for the dump command *)
  let _to_sexp { src; dst } =
    Sexp.List
      [ Path.to_sexp src
      ; Sexp.Atom "as"
      ; Path.to_sexp dst
      ]

  let db : t list ref = ref []

  let register t = db := t :: !db

  let promote { src; dst } =
    Errors.print_to_console (Format.sprintf "Promoting %s to %s.@."
      (Path.to_string_maybe_quoted src)
      (Path.to_string_maybe_quoted dst));
    Io.copy_file ~src ~dst ()
end

let clear_cache () =
  File.db := []

let () = Hooks.End_of_build.always clear_cache

module P = Utils.Persistent(struct
    type t = File.t list
    let name = "TO-PROMOTE"
    let version = 1
  end)

let db_file = Path.relative Path.build_dir ".to-promote"

let dump_db db =
  if Path.build_dir_exists () then begin
    match db with
    | [] -> if Path.exists db_file then Path.unlink_no_err db_file
    | l -> P.dump db_file l
  end

let load_db () = Option.value ~default:[] (P.load db_file)

let group_by_targets db =
  List.map db ~f:(fun { File. src; dst } ->
    (dst, src))
  |> Path.Map.of_list_multi
  (* Sort the list of possible sources for deterministic behavior *)
  |> Path.Map.map ~f:(List.sort ~compare:Path.compare)

type files_to_promote =
  | All
  | These of Path.t list * (Path.t -> unit)

let do_promote db files_to_promote =
  let by_targets = group_by_targets db  in
  let potential_build_contexts =
    match Path.readdir_unsorted Path.build_dir with
    | exception _ -> []
    | files ->
      List.filter_map files ~f:(fun fn ->
        if fn = "" || fn.[0] = '.' || fn = "install" then
          None
        else
          let path = Path.(relative build_dir) fn in
          Option.some_if (Path.is_directory path) path)
  in
  let dirs_to_clear_from_cache = Path.root :: potential_build_contexts in
  let promote_one dst srcs =
    match srcs with
    | [] -> assert false
    | src :: others ->
      (* We remove the files from the digest cache to force a rehash
         on the next run. We do this because on OSX [mtime] is not
         precise enough and if a file is modified and promoted
         quickly, it will look like it hasn't changed even though it
         might have. *)
      List.iter dirs_to_clear_from_cache ~f:(fun dir ->
        Utils.Cached_digest.remove (Path.append dir dst));
      File.promote { src; dst };
      List.iter others ~f:(fun path ->
        Format.eprintf " -> ignored %s.@."
          (Path.to_string_maybe_quoted path))
  in
  match files_to_promote with
  | All ->
    Path.Map.iteri by_targets ~f:promote_one;
    []
  | These (files, on_missing) ->
    let files =
      Path.Set.of_list files |> Path.Set.to_list
    in
    let by_targets =
      List.fold_left files ~init:by_targets ~f:(fun map fn ->
        match Path.Map.find by_targets fn with
        | None ->
          on_missing fn;
          map
        | Some srcs ->
          promote_one fn srcs;
          Path.Map.remove by_targets fn)
    in
    Path.Map.to_list by_targets
    |> List.concat_map ~f:(fun (dst, srcs) ->
      List.map srcs ~f:(fun src -> { File.src; dst }))

let finalize () =
  let db =
    if !Clflags.auto_promote then
      do_promote !File.db All
    else
      !File.db
  in
  dump_db db

let promote_files_registered_in_last_run files_to_promote =
  let db = load_db () in
  let db = do_promote db files_to_promote in
  dump_db db
