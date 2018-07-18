open Core
open Dsl

let (!^) id = Batteries.Int32.of_int (Id.value id)

module Constant = struct
  module T = struct
    type t = SpirV.id sexp_opaque * int [@@deriving sexp]
    let compare = compare
    let hash = Hashtbl.hash
  end

  include T
  include Comparable.Make(T)
  module Table = Hashtbl.Make(T)
end

module type Program_intf = sig
  val gen_id : 'a Type.t -> string -> 'a Id.t
  val register_type : 'a Type.t -> unit Id.t
  val register_constant : 'a Type.t -> int -> 'a Id.t

  val push_op : SpirV.op -> unit
  val push_block : branch:Spirv_module.branch -> next_label:SpirV.id -> unit
  val begin_function : string -> ('f, 'a, 'g) Arguments_spec.t -> ('g, 'h) Local_variables_spec.t -> 'b Type.t -> unit
  val end_function : unit -> unit

  val extract : unit -> Spirv_module.t
end

module MakeProgram(Unit : sig end) : Program_intf = struct
  let defining_function : bool ref = ref false
  let next_id : int ref = ref 0
  let blocks : Spirv_module.basic_block list ref = ref []
  let curr_block_label : SpirV.id ref = ref 0l
  let curr_block_ops : SpirV.op list ref = ref []

  let name_table : (string, int) Hashtbl.t = String.Table.create ()
  let type_table : (Type.Enum.t, SpirV.id) Hashtbl.t = Type.Enum.Table.create ()
  let constant_table : (Constant.t, SpirV.id) Hashtbl.t = Constant.Table.create ()
  let function_table : (string, Spirv_module.function_definition) Hashtbl.t = String.Table.create ()

  let gen_id type_ name =
    let id = !next_id in
    next_id := !next_id + 1;

    let next_name name =
      if Str.string_match (Str.regexp {|_\([0-9]+\)$|}) name 0 then
        let num = Str.matched_group 1 name in
        let num = string_of_int (int_of_string num + 1) in
        Str.replace_matched num name
      else
        name ^ "_0"
    in
    let rec register_name name =
      match Hashtbl.add name_table ~key:name ~data:id with
        | `Duplicate -> register_name (next_name name)
        | `Ok -> ()
    in
    register_name name;

    Id.Id (type_, name, id)


  let register_type type_ : unit Id.t =
    let name = Type.to_string type_ in
    let id_value = Hashtbl.find_or_add type_table (Type.Enum.T type_) ~default:(fun () -> !^(gen_id type_ name)) in
    Id.Id (Type.Type, name, Batteries.Int32.to_int id_value)

  let register_constant type_ val_ =
    let type_id = register_type type_ in
    let name = Printf.sprintf "c_%s_%d" (Id.name type_id) val_ in
    let id_value = Hashtbl.find_or_add constant_table (!^type_id, val_) ~default:(fun () -> !^(gen_id type_ name)) in
    Id.Id (type_, name, Batteries.Int32.to_int id_value)

  let push_op op = curr_block_ops := op :: !curr_block_ops
  let push_block ~branch ~next_label =
    let block = Spirv_module.(
      { basic_block_label = !curr_block_label;
        basic_block_body = List.rev !curr_block_ops;
        basic_block_branch = branch })
    in
    blocks := block :: !blocks;
    curr_block_label := next_label;
    curr_block_ops := []

  let define_function name return_type args vars ~f =
    assert (not !defining_function);
    defining_function := true;


    f ();
    push_block ~branch:FunctionEnd ~next_label:!^(gen_id Type.Label "fn_start");

    let fn =
      { function_return_type
      ; function_id
      ; function_control = SpirV.FunctionControlNone
      ; function_type
      ; function_parameters
      ; function_body = List.rev !blocks }
    in
    functions := fn :: !functions
    defining_function := false

  let extract () =
    { capabilities = []
    ; memory_model = (SpirV.AddressingModelLogical, SpirV.MemoryModelSimple)
    ; entry_points =
        [ { entry_point_execution_mode = SpirV.ExecutionModeLocalSize (1l, 1l, 1l)
          ; entry_point_execution_model = SpirV.ExecutionModelGLCompute
          ; entry_point_id = Hashtbl.find_exn functions "main"
          ; entry_point_name = "main"
          ; entry_point_interfaces = [] } ]
    ; decorations = []
    ; types = Hashtbl.to_alist type_table |> List.map ~f:(fun (type_, type_id) -> { type_id; type_value = spirv_type_value type_ })
    ; constants = Hashtbl.to_alist constant_table |> List.map ~f:(fun ((constant_type, constant_value), constant_id) -> { constant_type; constant_value; constant_id })
    ; global_variables = []
    ; functions = Hashtbl.data function_table }
end

module MakeCompiler(Program : Program_intf) = struct
  module Program = Program
  open Program

  let compile_value_op : type a b. a Op.Value.t -> a Id.t = fun op ->
    let open Type in
    let open Op.Value in

    let f : type a b. a Id.t -> b Id.t -> b Type.t -> (unit Id.t -> b Id.t -> SpirV.op) -> b Id.t = fun x y type_ create_fn ->
      let type_id = register_type type_ in
      let result_id = gen_id type_ op.result_name in
      push_op (create_fn type_id result_id);
      result_id
    in

    match op.op with
      | Or (x, y) -> f x y (Scalar Scalar.Bool) (fun t r -> `OpLogicalOr (!^t, !^r, !^x, !^y))
      | Add (x, y) ->f x y Arith_result (fun t r -> `OpIAddCarry (!^t, !^r, !^x, !^y))
      | Add_ignore_overflow (x, y) -> f x y (Scalar Scalar.Uint32) (fun t r -> `OpIAdd (!^t, !^r, !^x, !^y))
      | _ -> failwith "compile_value_op not fully implemented"

  let compile_action_op =
    let open Op.Action in
    function
      | Array_set _ -> failwith "Op.Action.Array_set: unimplemented"
      | Store (ptr, value) -> push_op (`OpStore (!^ptr, !^value, None))

  let rec compile = function
    | Declare_function (name, args, vars, return_type, body, continuation) ->
        begin_function name args return_type;

        let gen_arg = Arguments_spec.({ f = fun t -> gen_id t (name ^ "_arg_0") }) in
        let gen_var = Local_variables_spec.({ f = fun t -> gen_id (Type.Pointer t) (name ^ "_var_0") }) in

        body
          |> Arguments_spec.apply gen_arg args
          |> Local_variables_spec.apply gen_var vars
          |> compile;

        finalize_function ();
        compile (continuation function_id)

    | Value_op (op, continuation) ->
        compile (continuation (compile_value_op op))

    | Action_op (op, continuation) ->
        compile_action_op op;
        compile (continuation ())

    | Do_if { cond; then_; after } ->
        let then_label = gen_id Type.Label "if_then" in
        let after_label = gen_id Type.Label "if_after" in

        push_block
          ~branch:(BranchConditional (!^cond, !^then_label, !^after_label))
          ~next_label:!^then_label;

        compile then_;
        push_block
          ~branch:(Branch !^after_label)
          ~next_label:!^after_label;

        compile (after ())

  (*
    | If { cond; then_; after } ->
        let then_label = gen_id Type.Label "if_then" in
        let after_label = gen_id Type.Label "if_after" in

        push_block
          ~branch:(BranchConditional (!^cond, !^then_label, !^after_label))
          ~next_label:!^then_label;

        then_;
        push_block
          ~branch:(Branch !^after_label)
          ~next_label:!^after_label;
   *)

    | For { var_ptr; range = (low, high); body; after } ->
        let var_type = Type.pointer_elt (Id.typ var_ptr) in
        let var_type_id = register_type var_type in
        let bool_type_id = register_type (Type.Scalar Type.Scalar.Bool) in

        let const_1 = register_constant var_type 1 in

        let header_label = gen_id Type.Label "loop_header" in
        let merge_label = gen_id Type.Label "loop_merge" in
        let body_label = gen_id Type.Label "loop_body" in
        let continue_label = gen_id Type.Label "loop_continue" in
        let after_label = gen_id Type.Label "loop_after" in
        let var_0 = gen_id var_type "var_0" in
        let var_1 = gen_id var_type "var_1" in
        let cond = gen_id (Type.Scalar Type.Scalar.Bool) "cond" in

        push_op (`OpStore (!^var_ptr, !^low, None));
        push_block
          ~branch:(Branch !^header_label)
          ~next_label:!^header_label;

        push_op (`OpLoopMerge (!^merge_label, !^continue_label, []));
        push_block
          ~branch:(Branch !^merge_label)
          ~next_label:!^merge_label;

        push_op (`OpLoad (!^var_type_id, !^var_0, !^var_ptr, None));
        push_op (`OpSLessThanEqual (!^bool_type_id, !^cond, !^var_0, !^high));
        push_block
          ~branch:(BranchConditional (!^cond, !^body_label, !^after_label))
          ~next_label:!^after_label;

        compile (body var_0);
        push_block
          ~branch:(Branch !^continue_label)
          ~next_label:!^continue_label;

        push_op (`OpIAdd (!^var_type_id, !^var_1, !^var_0, !^const_1));
        push_op (`OpStore (!^var_ptr, !^var_1, None));
        push_block
          ~branch:(Branch !^header_label)
          ~next_label:!^after_label;

        compile (after ())

    | Set_prefix _ ->
        failwith "not implemented: Dsl.Set_prefix"
    | Phi _ ->
        failwith "not implemented: Dsl.Phi"
    | Pure _ ->
        ()
end

let compile dsl =
  let Compiler = MakeCompiler(MakeProgram(struct end)) in
  Compiler.compile dsl;
  let words =
    Compile.Program.extract ()
      |> Spirv_module.compile
      |> SpirV.compile_to_words
  in

  let ch = Unix.open_process_out "spirv-val" in
  List.map words ~f:(Out_channel.output_value ch);
  Out_channel.flush ch;
  (match close_process_in ch with
    | Ok () -> ()
    | Error (`Exit_non_zero exit) ->
        failwith (Printf.sprintf "compiled spirv failed validation (exit code %d)" exit)
    | Error (`Signal signal) ->
        failwith (Printf.sprintf "spirv-val process received unexpected signal (%s)" (Signal.to_string signal)));

  words
