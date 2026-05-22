(* Shared dumping helpers used by [dump_circuit_impl.ml] (standalone
   sub-circuit fixtures) and [compile.ml] (production-derived top-level
   step / wrap fixtures). Factors out the
     1. constraint-logger setup that captures per-constraint label
        events into [_labels.jsonl] AND per-row label stacks into the
        backend's [gate_label_stack] (read by [dump_gate_labels]),
     2. fixture file writing,
     3. monotonic [%c]-counter substitution in env-var-templated paths,
     4. polymorphic [constraint_type_name] (works on both Step and
        Wrap impls — both instantiate the same
        [Plonk_constraint.basic] variant),
   so every dump path emits byte-equivalent fixture data. *)

open Core_kernel
module PC = Kimchi_pasta_snarky_backend.Plonk_constraint_system.Plonk_constraint

let json_escape s =
  String.concat_map s ~f:(fun c ->
      match c with
      | '"' ->
          "\\\""
      | '\\' ->
          "\\\\"
      | '\n' ->
          "\\n"
      | _ ->
          String.make 1 c )

(** Map any [Plonk_constraint.basic] constructor to its tag string for
    [_labels.jsonl] output. Polymorphic over [(fv, fp) basic], so it
    works for both [Impls.Step.Constraint.t] and
    [Impls.Wrap.Constraint.t] without per-impl duplication. *)
let constraint_type_name : type fv fp. (fv, fp) PC.basic -> string =
 fun c ->
  match c with
  | Boolean _ ->
      "Boolean"
  | Equal _ ->
      "Equal"
  | Square _ ->
      "Square"
  | R1CS _ ->
      "R1CS"
  | Basic _ ->
      "Basic"
  | Poseidon _ ->
      "Poseidon"
  | EC_add_complete _ ->
      "EC_add_complete"
  | EC_scale _ ->
      "EC_scale"
  | EC_endoscale _ ->
      "EC_endoscale"
  | EC_endoscalar _ ->
      "EC_endoscalar"
  | Lookup _ ->
      "Lookup"
  | RangeCheck0 _ ->
      "RangeCheck0"
  | RangeCheck1 _ ->
      "RangeCheck1"
  | ForeignFieldAdd _ ->
      "ForeignFieldAdd"
  | ForeignFieldMul _ ->
      "ForeignFieldMul"
  | Xor _ ->
      "Xor"
  | Rot64 _ ->
      "Rot64"
  | AddFixedLookupTable _ ->
      "AddFixedLookupTable"
  | AddRuntimeTableCfg _ ->
      "AddRuntimeTableCfg"
  | Raw _ ->
      "Raw"

(** Monotonic counters for [%c] substitution in env-var-templated
    fixture paths. Owned here so both step and wrap dump sites share
    the same numbering scheme; multi-rule compiles emit one fixture
    per CS via successive [%c] values. *)
let step_counter = ref 0

let wrap_counter = ref 0

let bump_counter c =
  let n = !c in
  incr c ; n

let substitute_counter ~counter path =
  String.substr_replace_all path ~pattern:"%c"
    ~with_:(Int.to_string (bump_counter counter))

(** Register a constraint logger that pushes/pops a [with_label] stack
    into [set_gate_label_stack] and accumulates per-constraint events.
    Returns the events ref (read after the circuit runs and the logger
    is cleared via [teardown_logger]). *)
let setup_logger ~set_constraint_logger ~set_gate_label_stack
    ~constraint_type_name =
  let events = ref [] in
  let label_stack = ref [] in
  set_constraint_logger (fun ?at_label_boundary constraint_opt ->
      ( match at_label_boundary with
      | Some (`Start, lab) ->
          label_stack := lab :: !label_stack ;
          set_gate_label_stack !label_stack
      | Some (`End, _lab) ->
          label_stack :=
            ( match !label_stack with
            | _ :: rest ->
                rest
            | [] ->
                [] ) ;
          set_gate_label_stack !label_stack
      | None ->
          () ) ;
      match constraint_opt with
      | Some c ->
          let path = String.concat ~sep:"/" (List.rev !label_stack) in
          events := (path, constraint_type_name c) :: !events
      | None ->
          () ) ;
  events

let teardown_logger ~clear_constraint_logger ~set_gate_label_stack =
  clear_constraint_logger () ;
  set_gate_label_stack []

(** Write the four-file fixture: [<stem>.json],
    [<stem>_cached_constants.json], [<stem>_gate_labels.jsonl],
    [<stem>_labels.jsonl]. *)
let write_fixture_files ~stem ~to_json ~dump_cached_constants
    ~dump_gate_labels cs ~events =
  Out_channel.write_all (stem ^ ".json") ~data:(to_json cs ^ "\n") ;
  Out_channel.write_all
    (stem ^ "_cached_constants.json")
    ~data:(dump_cached_constants cs ^ "\n") ;
  Out_channel.write_all
    (stem ^ "_gate_labels.jsonl")
    ~data:(dump_gate_labels cs ^ "\n") ;
  let lines =
    List.map events ~f:(fun (lp, ctype) ->
        Printf.sprintf "{\"label\":\"%s\",\"constraint\":\"%s\"}"
          (json_escape lp) (json_escape ctype) )
  in
  Out_channel.write_all
    (stem ^ "_labels.jsonl")
    ~data:(String.concat ~sep:"\n" lines ^ "\n")

(** Per-call dump configuration. Bundles the env-var name + counter
    + every impl-specific function the dump path needs, so callers
    pass one record instead of 9 keyword arguments to each helper.

    Type parameters: ['cs] = the backend [R1CS_constraint_system.t];
    ['constr] = the backend's [Constraint.t] (= [(fv, fp) PC.basic]
    for both Step and Wrap). *)
type ('cs, 'constr) cfg =
  { env_var : string
  ; counter : int ref
  ; set_constraint_logger :
         (   ?at_label_boundary:[ `Start | `End ] * string
          -> 'constr option
          -> unit )
      -> unit
  ; clear_constraint_logger : unit -> unit
  ; set_gate_label_stack : string list -> unit
  ; constraint_type_name : 'constr -> string
  ; to_json : 'cs -> string
  ; dump_cached_constants : 'cs -> string
  ; dump_gate_labels : 'cs -> string
  }

(** [setup cfg] returns [None] when [cfg.env_var] is unset; otherwise
    registers the constraint logger and returns the events ref. Call
    this BEFORE the CS-construction code. The matching [teardown] /
    [emit] pair must use the same returned [events_opt]. *)
let setup cfg =
  match Sys.getenv_opt cfg.env_var with
  | None ->
      None
  | Some _ ->
      Some
        (setup_logger ~set_constraint_logger:cfg.set_constraint_logger
           ~set_gate_label_stack:cfg.set_gate_label_stack
           ~constraint_type_name:cfg.constraint_type_name )

(** [teardown cfg events_opt] clears the logger if [setup] registered
    one. Call after constraint emission has finished. *)
let teardown cfg events_opt =
  match events_opt with
  | None ->
      ()
  | Some _ ->
      teardown_logger
        ~clear_constraint_logger:cfg.clear_constraint_logger
        ~set_gate_label_stack:cfg.set_gate_label_stack

(** [emit cfg events_opt cs] writes the fixture files when
    [cfg.env_var] is set, substituting [%c] in the path with the
    current counter value (and bumping the counter). *)
let emit cfg events_opt cs =
  match Sys.getenv_opt cfg.env_var with
  | None ->
      ()
  | Some stem_tmpl ->
      let events =
        match events_opt with Some r -> List.rev !r | None -> []
      in
      let stem = substitute_counter ~counter:cfg.counter stem_tmpl in
      write_fixture_files ~stem ~to_json:cfg.to_json
        ~dump_cached_constants:cfg.dump_cached_constants
        ~dump_gate_labels:cfg.dump_gate_labels cs ~events

(** [with_dump cfg ~build_cs] is the single entry point most callers
    should use. Wraps [build_cs] with [setup] / [teardown] / [emit]
    in the right order. Use the lower-level [setup] / [teardown] /
    [emit] primitives only when you need to interleave additional
    work between build and teardown (e.g. the step site uses
    [constraint_system_manual]'s separate [run_circuit] /
    [finish_computation] phases). *)
let with_dump cfg ~build_cs =
  let events_opt = setup cfg in
  let cs = build_cs () in
  teardown cfg events_opt ;
  emit cfg events_opt cs ;
  cs
