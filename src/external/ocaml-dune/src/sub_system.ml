open! Stdune
open! Import

include Sub_system_intf

module Register_backend(M : Backend) = struct
  include Dune_file.Sub_system_info.Register(M.Info)
  include Lib.Sub_system.Register(struct
      include M
      type Lib.Sub_system.t += T of t
      let encode = Some encode
    end)

  let top_closure l ~deps =
    match
      Top_closure.Int.top_closure l
        ~key:(fun t -> Lib.unique_id (M.lib t))
        ~deps:(fun t ->
          match deps t with
          | Ok l    -> l
          | Error e -> raise_notrace e)
    with
    | Ok _ as res -> res
    | Error _ ->
      (* Lib.t values can't be cyclic, so we can't have cycles here *)
      assert false
    | exception exn -> Error exn

  module Set =
    Set.Make(struct
      type t = M.t
      let compare a b =
        compare
          (Lib.unique_id (M.lib a))
          (Lib.unique_id (M.lib b))
    end)

  let resolve db (loc, name) =
    let open Result.O in
    Lib.DB.resolve db (loc, name) >>= fun lib ->
    match get lib with
    | None ->
      Error (Errors.exnf loc "%a is not %s %s" Lib_name.pp_quoted name
               M.desc_article
               (M.desc ~plural:false))
    | Some t -> Ok t

  module Selection_error = struct
    type t =
      | Too_many_backends of M.t list
      | No_backend_found
      | Other of exn

    let to_exn t ~loc =
      match t with
      | Too_many_backends backends ->
        Errors.exnf loc
          "Too many independent %s found:\n%s"
          (M.desc ~plural:true)
          (String.concat ~sep:"\n"
             (List.map backends ~f:(fun t ->
                let lib = M.lib t in
                sprintf "- %S in %s"
                  (Lib_name.to_string (Lib.name lib))
                  (Path.to_string_maybe_quoted (Lib.src_dir lib)))))
      | No_backend_found ->
        Errors.exnf loc "No %s found." (M.desc ~plural:false)
      | Other exn ->
        exn

    let or_exn res ~loc =
      match res with
      | Ok _ as x -> x
      | Error t -> Error (to_exn t ~loc)

    let wrap = function
      | Ok _ as x -> x
      | Error exn -> Error (Other exn)
  end
  open Selection_error

  let written_by_user_or_scan ~written_by_user ~to_scan =
    match
      match written_by_user with
      | Some l -> l
      | None   -> List.filter_map to_scan ~f:get
    with
    | [] -> Error No_backend_found
    | l -> Ok l

  let select_extensible_backends ?written_by_user ~extends to_scan =
    let open Result.O in
    written_by_user_or_scan ~written_by_user ~to_scan
    >>= fun backends ->
    wrap (top_closure backends ~deps:extends)
    >>= fun backends ->
    let roots =
      let all = Set.of_list backends in
      List.fold_left backends ~init:all ~f:(fun acc t ->
        Set.diff acc (Set.of_list (Result.ok_exn (extends t))))
      |> Set.to_list
    in
    if List.length roots = 1 then
      Ok backends
    else
      Error (Too_many_backends roots)

  let select_replaceable_backend ?written_by_user ~replaces to_scan =
    let open Result.O in
    written_by_user_or_scan ~written_by_user ~to_scan
    >>= fun backends ->
    wrap (Result.List.concat_map backends ~f:replaces)
    >>= fun replaced_backends ->
    match
      Set.diff (Set.of_list backends) (Set.of_list replaced_backends)
      |> Set.to_list
    with
    | [b] -> Ok b
    | l   -> Error (Too_many_backends l)
end

type Lib.Sub_system.t +=
    Gen of (Library_compilation_context.t -> unit)

module Register_end_point(M : End_point) = struct
  include Dune_file.Sub_system_info.Register(M.Info)

  let gen info (c : Library_compilation_context.t) =
    let open Result.O in
    let backends =
      Lib.Compile.direct_requires c.compile_info >>= fun deps ->
      Lib.Compile.pps             c.compile_info >>= fun pps  ->
      (match M.Info.backends info with
       | None -> Ok None
       | Some l ->
         Result.List.map l ~f:(M.Backend.resolve (Scope.libs c.scope))
         >>| Option.some)
      >>= fun written_by_user ->
      M.Backend.Selection_error.or_exn ~loc:(M.Info.loc info)
        (M.Backend.select_extensible_backends
           ?written_by_user
           ~extends:M.Backend.extends
           (deps @ pps))
    in
    let fail, backends =
      match backends with
      | Ok backends -> (None, backends)
      | Error e ->
        (Some { fail = fun () -> raise e },
         [])
    in
    match fail with
    | None -> M.gen_rules c ~info ~backends
    | Some fail ->
      Super_context.prefix_rules c.super_context (Build.fail fail)
        ~f:(fun () -> M.gen_rules c ~info ~backends)

  include
    Lib.Sub_system.Register
      (struct
        module Info = M.Info
        type t = Library_compilation_context.t -> unit
        type Lib.Sub_system.t += T = Gen
        let instantiate ~resolve:_ ~get:_ _id info = gen info
        let encode = None
      end)
end

let gen_rules (c : Library_compilation_context.t) =
  List.iter (Lib.Compile.sub_systems c.compile_info) ~f:(function
    | Gen gen -> gen c
    | _ -> ())
