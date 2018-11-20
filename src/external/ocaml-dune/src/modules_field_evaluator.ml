open Stdune

module Buildable = Dune_file.Buildable

type t =
  { all_modules : Module.Name_map.t
  ; virtual_modules : Module.Name_map.t
  }

let eval =
  let module Value = struct
    type t = (Module.t, Module.Name.t) result

    type key = Module.Name.t

    let key = function
      | Error s -> s
      | Ok m -> Module.name m
  end in
  let module Eval = Ordered_set_lang.Make_loc(Module.Name)(Value) in
  let parse ~all_modules ~fake_modules ~loc s =
    let name = Module.Name.of_string s in
    match Module.Name.Map.find all_modules name with
    | Some m -> Ok m
    | None ->
      fake_modules := Module.Name.Map.add !fake_modules name loc;
      Error name
  in
  fun ~all_modules ~standard osl ->
    let fake_modules = ref Module.Name.Map.empty in
    let parse = parse ~fake_modules ~all_modules in
    let standard = Module.Name.Map.map standard ~f:(fun m -> Ok m) in
    let modules = Eval.eval_unordered ~parse ~standard osl in
    ( !fake_modules
    , Module.Name.Map.filter_map modules ~f:(fun (loc, m) ->
        match m with
        | Ok m -> Some (loc, m)
        | Error s ->
          Errors.fail loc "Module %a doesn't exist." Module.Name.pp s)
    )

module Module_errors = struct
  type t =
    { missing_modules      : (Loc.t * Module.t) list
    ; missing_intf_only    : (Loc.t * Module.t) list
    ; virt_intf_overlaps   : (Loc.t * Module.t) list
    ; private_virt_modules : (Loc.t * Module.t) list
    }

  let empty =
    { missing_modules      = []
    ; missing_intf_only    = []
    ; virt_intf_overlaps   = []
    ; private_virt_modules = []
    }

  let map { missing_modules ; missing_intf_only ; virt_intf_overlaps
          ; private_virt_modules } ~f =
    { missing_modules = f missing_modules
    ; missing_intf_only = f missing_intf_only
    ; virt_intf_overlaps = f virt_intf_overlaps
    ; private_virt_modules = f private_virt_modules
    }
end

let find_errors ~modules ~intf_only ~virtual_modules ~private_modules =
  let missing_modules =
    Module.Name.Map.fold intf_only ~init:[]
      ~f:(fun ((_, (module_ : Module.t)) as module_loc) acc ->
        if Module.has_impl module_ then
          module_loc :: acc
        else
          acc)
  in
  let errors =
    Module.Name.Map.fold virtual_modules ~init:Module_errors.empty
      ~f:(fun (_, (module_ : Module.t) as module_loc) acc ->
        if Module.has_impl module_ then
          { acc with missing_modules = module_loc :: acc.missing_modules }
        else if Module.Name.Map.mem intf_only (Module.name module_) then
          { acc with virt_intf_overlaps = module_loc :: acc.virt_intf_overlaps
          }
        else if Module.Name.Map.mem private_modules (Module.name module_) then
          { acc with private_virt_modules =
                       module_loc :: acc.private_virt_modules
          }
        else
          acc)
  in
  let missing_intf_only =
    Module.Name.Map.fold modules ~init:[]
      ~f:(fun (_, (module_ : Module.t) as module_loc) acc ->
        if Module.has_impl module_ then
          acc
        else if not (Module.Name.Map.mem intf_only (Module.name module_))
             && not (Module.Name.Map.mem virtual_modules (Module.name module_))
        then
          module_loc :: acc
        else
          acc) in
  assert (List.is_empty errors.missing_intf_only);
  { errors with
    missing_modules = List.rev_append errors.missing_modules missing_modules
  ; missing_intf_only
  }
  |> Module_errors.map ~f:List.rev

let check_invalid_module_listing ~(buildable : Buildable.t) ~intf_only
      ~modules ~virtual_modules ~private_modules =
  let { Module_errors.
        missing_modules
      ; missing_intf_only
      ; virt_intf_overlaps
      ; private_virt_modules
      } = find_errors ~modules ~intf_only ~virtual_modules ~private_modules
  in
  let uncapitalized =
    List.map ~f:(fun (_, m) -> Module.name m |> Module.Name.uncapitalize) in
  let line_list modules =
    List.map ~f:(fun (_, m) ->
      Module.name m |> Module.Name.to_string |> sprintf "- %s") modules
    |> String.concat ~sep:"\n"
  in
  begin match private_virt_modules with
  | [] -> ()
  | (loc, _) :: _ ->
    Errors.fail loc
      "The following modules are declared as virtual and private: \
       \n%s\nThis is not possible."
      (line_list private_virt_modules)
  end;
  begin match virt_intf_overlaps with
  | [] -> ()
  | (loc, _) :: _ ->
    Errors.fail loc
      "These modules appear in the virtual_libraries \
       and modules_without_implementation fields: \
       \n%s\nThis is not possible."
      (line_list virt_intf_overlaps)
  end;
  if missing_intf_only <> [] then begin
    match Ordered_set_lang.loc buildable.modules_without_implementation with
    | None ->
      Errors.warn buildable.loc
        "Some modules don't have an implementation.\
         \nYou need to add the following field to this stanza:\
         \n\
         \n  %s\
         \n\
         \nThis will become an error in the future."
        (let tag = Dune_lang.unsafe_atom_of_string
                     "modules_without_implementation" in
         let modules =
           missing_intf_only
           |> uncapitalized
           |> List.map ~f:Dune_lang.Encoder.string
         in
         Dune_lang.to_string ~syntax:Dune (List (tag :: modules)))
    | Some loc ->
      Errors.warn loc
        "The following modules must be listed here as they don't \
         have an implementation:\n\
         %s\n\
         This will become an error in the future."
        (line_list missing_intf_only)
  end;
  begin match missing_modules with
  | [] -> ()
  | (loc, module_) :: _ ->
    (* CR-soon jdimino for jdimino: report all errors *)
    Errors.fail loc
      "Module %a has an implementation, it cannot be listed here"
      Module.Name.pp (Module.name module_)
  end

let eval ~modules:(all_modules : Module.Name_map.t)
      ~buildable:(conf : Buildable.t) ~virtual_modules
      ~private_modules =
  let (fake_modules, modules) =
    eval ~standard:all_modules ~all_modules conf.modules in
  let (fake_modules, intf_only) =
    let (fake_modules', intf_only) =
      eval ~standard:Module.Name.Map.empty ~all_modules
        conf.modules_without_implementation in
    ( Module.Name.Map.superpose fake_modules' fake_modules
    , intf_only
    )
  in
  let (fake_modules, virtual_modules) =
    match virtual_modules with
    | None -> (fake_modules, Module.Name.Map.empty)
    | Some virtual_modules ->
      let (fake_modules', virtual_modules) =
        eval ~standard:Module.Name.Map.empty ~all_modules
          virtual_modules in
      ( Module.Name.Map.superpose fake_modules' fake_modules
      , virtual_modules
      )
  in
  let (fake_modules, private_modules) =
    let (fake_modules', private_modules) =
      eval ~standard:Module.Name.Map.empty ~all_modules private_modules
    in
    ( Module.Name.Map.superpose fake_modules' fake_modules
    , private_modules
    )
  in
  Module.Name.Map.iteri fake_modules ~f:(fun m loc ->
    Errors.warn loc "Module %a is excluded but it doesn't exist."
      Module.Name.pp m
  );
  check_invalid_module_listing ~buildable:conf ~intf_only
    ~modules ~virtual_modules ~private_modules;
  let drop_locs = Module.Name.Map.map ~f:snd in
  { all_modules =
      Module.Name.Map.map modules ~f:(fun (_, m) ->
        if Module.Name.Map.mem private_modules (Module.name m) then
          Module.set_private m
        else
          m)
  ; virtual_modules = drop_locs virtual_modules
  }
