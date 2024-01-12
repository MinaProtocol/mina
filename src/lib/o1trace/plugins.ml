open Core_kernel

(* TODO: ensure plugin names are unique (use encapsulated type as proof of functor application) *)

type proof_of_registration = I_have_been_registered

let registry = ref String.Set.empty

module type Plugin_spec_intf = sig
  type state [@@deriving sexp_of]

  val name : string

  (* TODO: pass parent in (when available) for proper flame graph plugin *)
  val init_state : string -> state
end

module type Registered_plugin_spec_intf = sig
  include Plugin_spec_intf

  val registration : proof_of_registration

  val state_id : state Type_equal.Id.t
end

module type Plugin_intf = sig
  include Registered_plugin_spec_intf

  val on_job_enter : Thread.Fiber.t -> unit

  val on_job_exit : Thread.Fiber.t -> Time_ns.Span.t -> unit
end

module Register_plugin (Plugin_spec : Plugin_spec_intf) () :
  Registered_plugin_spec_intf with type state = Plugin_spec.state = struct
  include Plugin_spec

  let () =
    if Set.mem !registry name then
      failwithf "O1trace plugin already registered: %s" name ()
    else registry := Set.add !registry name

  let registration = I_have_been_registered

  let state_id = Type_equal.Id.create ~name sexp_of_state
end

let plugins : (module Plugin_intf) String.Table.t = String.Table.create ()

let plugin_state (type a)
    (module Plugin : Registered_plugin_spec_intf with type state = a) thread =
  match Thread.load_state thread Plugin.state_id with
  | Some state ->
      state
  | None ->
      let state = Plugin.init_state thread.name in
      Thread.set_state thread Plugin.state_id state ;
      state

let enable_plugin (module Plugin : Plugin_intf) =
  Hashtbl.set plugins ~key:Plugin.name ~data:(module Plugin)

let disable_plugin (module Plugin : Plugin_intf) =
  Hashtbl.remove plugins Plugin.name

let dispatch f = Hashtbl.iter plugins ~f
