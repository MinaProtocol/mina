open Core
open Dsl

(* TODO: Nathan fixme *)
module Batteries = struct
  module Int32 = struct
    let of_int _ = failwith "TODO: Nathan fixme"

    let to_int _ = failwith "TODO: Nathan fixme"
  end

  module Big_int = struct
    let of_int _ = failwith "TODO"
  end
end

let ( !^ ) id = Batteries.Int32.of_int (Id.value id)

module Constant = struct
  module T = struct
    type t = Spirv.id sexp_opaque * int [@@deriving sexp]

    let compare = compare

    let hash = Hashtbl.hash
  end

  include T
  include Comparable.Make (T)
  module Table = Hashtbl.Make (T)
end

module type Program_intf = sig
  val gen_id : 'a Type.t -> string -> 'a Id.t

  val register_type : 'a Type.t -> unit Id.t

  val register_constant : 'a Type.t -> int -> 'a Id.t

  val push_op : Spirv.op -> unit

  val push_block : branch:Spirv_module.Branch.t -> next_label:Spirv.id -> unit

  val define_function :
       string
    -> ('types, 'f, 'g) Arguments_spec.t
    -> ('vars, 'g, 'h Id.t Dsl.t) Local_variables_spec.t
    -> 'ret Type.t
    -> 'f
    -> f:('h Id.t Dsl.t -> 'ret Id.t)
    -> ('types Type.List.t, 'ret) Function.t Id.t

  val extract : unit -> Spirv_module.t
end

module Make_program () : Program_intf = struct
  let defining_function : bool ref = ref false

  let next_id : int ref = ref 1

  let blocks : Spirv_module.Basic_block.t list ref = ref []

  let curr_block_label : Spirv.id ref = ref 0l

  let curr_block_ops : Spirv.op list ref = ref []

  let name_table : (string, int) Hashtbl.t = String.Table.create ()

  let types : (Type.E.t * Spirv.id) list ref = ref []

  let type_table : (Type.E.t, Spirv.id) Hashtbl.t = Type.E.Table.create ()

  let constant_table : (Constant.t, Spirv.id) Hashtbl.t =
    Constant.Table.create ()

  let function_table : (string, Spirv_module.Function_definition.t) Hashtbl.t =
    String.Table.create ()

  let gen_id type_ name =
    let id = !next_id in
    incr next_id ;
    let next_name name =
      failwith "TODO: Fixme Nathan"
      (*if Str.string_match (Str.regexp {|_\([0-9]+\)$|}) name 0 then*)
      (*let num = Str.matched_group 1 name in*)
      (*let num = string_of_int (int_of_string num + 1) in*)
      (*Str.replace_matched num name*)
      (*else name ^ "_0"*)
    in
    let rec register_name name =
      match Hashtbl.add name_table ~key:name ~data:id with
      | `Duplicate -> register_name (next_name name)
      | `Ok -> ()
    in
    register_name name ;
    Printf.printf "id: %s %d\n" (Type.to_string type_) id ;
    Id.Id (type_, name, id)

  let register_type type_ : unit Id.t =
    let name = Type.to_string type_ in
    let id_value =
      Hashtbl.find_or_add type_table (Type.E.T type_) ~default:(fun () ->
          let id = gen_id Type.Type name in
          types := (Type.E.T type_, !^id) :: !types ;
          !^id )
    in
    Id.Id (Type.Type, name, Batteries.Int32.to_int id_value)

  let register_constant type_ val_ =
    let type_id = register_type type_ in
    let name = Printf.sprintf "c_%s_%d" (Id.name type_id) val_ in
    let id_value =
      Hashtbl.find_or_add constant_table (!^type_id, val_) ~default:(fun () ->
          !^(gen_id type_ name) )
    in
    Id.Id (type_, name, Batteries.Int32.to_int id_value)

  let push_op op = curr_block_ops := op :: !curr_block_ops

  let push_block ~branch ~next_label =
    let block =
      let open Spirv_module.Basic_block in
      {label= !curr_block_label; body= List.rev !curr_block_ops; branch}
    in
    blocks := block :: !blocks ;
    curr_block_label := next_label ;
    curr_block_ops := []

  let define_function : type types args vars f g h ret.
         string
      -> (types, f, g) Arguments_spec.t
      -> (vars, g, h Id.t Dsl.t) Local_variables_spec.t
      -> ret Type.t
      -> f
      -> f:(h Id.t Dsl.t -> ret Id.t)
      -> (types Type.List.t, ret) Function.t Id.t =
   fun name args vars return_type body ~f ->
    assert (not !defining_function) ;
    defining_function := true ;
    let arg_types, arg_ids, body_with_args =
      let open Arguments_spec in
      apply args {generate= (fun t -> gen_id t (name ^ "_arg_0"))} body
    in
    let var_ids, applied_body =
      let open Local_variables_spec in
      apply vars
        {generate= (fun t -> gen_id (Type.Pointer t) (name ^ "_var_0"))}
        body_with_args
    in
    let parameters =
      let open Arguments_spec in
      map_ids args arg_ids
        { map_id=
            (fun id ->
              let open Spirv_module.Function_parameter in
              {type_= !^ (register_type (Id.typ id)); id= !^id} ) }
    in
    let variables =
      let open Local_variables_spec in
      map_ids vars var_ids
        { map_id=
            (fun id ->
              let open Spirv_module.Variable_declaration in
              { type_= !^ (register_type (Id.typ id))
              ; id= !^id
              ; storage_class= Spirv.StorageClassFunction
              ; initializer_= None } ) }
    in
    let return_type_id = register_type return_type in
    let type_ = Type.Function (arg_types, return_type) in
    let type_id = register_type type_ in
    let id = gen_id type_ name in
    blocks := [] ;
    curr_block_label := !^ (gen_id Type.Label "fn_start") ;
    curr_block_ops := [] ;
    let return_id = f applied_body in
    let branch =
      if Type.is_void (Id.typ return_id) then Spirv_module.Branch.Return
      else Spirv_module.Branch.ReturnValue !^return_id
    in
    push_block ~branch ~next_label:!^ (gen_id Type.Label "fn_start") ;
    let fn =
      let open Spirv_module.Function_definition in
      { return_type= !^return_type_id
      ; id= !^id
      ; control= []
      ; type_= !^type_id
      ; parameters
      ; variables
      ; body= List.rev !blocks }
    in
    if Hashtbl.add function_table ~key:name ~data:fn = `Duplicate then
      failwith (Printf.sprintf "function with name %s already exists" name) ;
    defining_function := false ;
    id

  let rec spirv_type_value : Type.E.t -> Spirv_module.Type.t =
    let module SMT = Spirv_module.Type in
    let open Type in
    let open Type.E in
    function
      | T Uint32 -> SMT.Int (32l, false)
      | T Bool -> SMT.Bool
      (* TODO: pointers of different storage classes *)
      | T (Pointer t) ->
          SMT.Pointer (Spirv.StorageClassFunction, !^(register_type t))
      | T (Array _) -> failwith "spirv_type_value: Array unimplemented"
      | T (Struct types) ->
          let type_ids =
            Type.List.(map types {f= (fun t -> !^(register_type t))})
          in
          SMT.Struct type_ids
      | T (Function (arg_types, return_type)) ->
          let arg_type_ids =
            Type.List.(map arg_types {f= (fun t -> !^(register_type t))})
          in
          SMT.Function (!^ (register_type return_type), arg_type_ids)
      | T Type ->
          failwith "spirv_type_value: cannot create spirv type from Type.Type"
      | T Label ->
          failwith "spirv_type_value: cannot create spirv type from Type.Label"
      | T Void -> SMT.Void

  let extract () =
    let open Spirv in
    let open Spirv_module in
    { capabilities= [CapabilityShader]
    ; memory_model= (AddressingModelLogical, MemoryModelSimple)
    ; entry_points=
        (let open Spirv_module.Entry_point in
        [ { execution_mode= ExecutionModeLocalSize (1l, 1l, 1l)
          ; execution_model= ExecutionModelGLCompute
          ; id=
              (let open Spirv_module.Function_definition in
              (Hashtbl.find_exn function_table "main").id)
          ; name= "main"
          ; interfaces= [] } ])
    ; decorations= []
    ; types=
        (let open Spirv_module.Type_declaration in
        List.map (List.rev !types) ~f:(fun (type_, id) ->
            {id; value= spirv_type_value type_} ))
    ; constants=
        (let open Spirv_module.Constant_declaration in
        Hashtbl.to_alist constant_table
        |> List.map ~f:(fun ((type_, value), id) ->
               {type_; value= BigInt (Batteries.Big_int.of_int value); id} ))
    ; global_variables= []
    ; functions= Hashtbl.data function_table }
end

module Make_compiler (Program : Program_intf) = struct
  module Program = Program
  open Program

  let create_value_op : type a.
      a Op.Value.op -> unit Id.t -> a Id.t -> Spirv.op =
    let open Op.Value in
    function
      | Or (x, y) -> fun t r -> `OpLogicalOr (!^t, !^r, !^x, !^y)
      | Add (x, y) -> fun t r -> `OpIAddCarry (!^t, !^r, !^x, !^y)
      | Add_ignore_overflow (x, y) -> fun t r -> `OpIAdd (!^t, !^r, !^x, !^y)
      | Sub (x, y) -> fun t r -> `OpISubBorrow (!^t, !^r, !^x, !^y)
      | Sub_ignore_overflow (x, y) -> fun t r -> `OpISub (!^t, !^r, !^x, !^y)
      | Mul (x, y) -> fun t r -> `OpUMulExtended (!^t, !^r, !^x, !^y)
      | Mul_ignore_overflow (x, y) -> fun t r -> `OpIMul (!^t, !^r, !^x, !^y)
      | Div_ignore_remainder (x, y) -> fun t r -> `OpUDiv (!^t, !^r, !^x, !^y)
      | Bitwise_or (x, y) -> fun t r -> `OpBitwiseOr (!^t, !^r, !^x, !^y)
      | Less_than (x, y) -> fun t r -> `OpULessThan (!^t, !^r, !^x, !^y)
      | Equal (x, y) -> fun t r -> `OpIEqual (!^t, !^r, !^x, !^y)
      | Array_access (a, i) -> fun t r -> `OpAccessChain (!^t, !^r, !^a, [!^i])
      | Struct_get (s, i) ->
          fun t r ->
            `OpCompositeExtract
              ( !^t
              , !^r
              , !^s
              , [!^ (register_constant Type.Uint32 (Elem.index i))] )
      | Load p -> fun t r -> `OpLoad (!^t, !^r, !^p, None)

  let compile_value_op : type a. a Op.Value.t -> a Id.t =
   fun op ->
    let open Type in
    let open Op.Value in
    let type_ = Op.Value.typ op.op in
    let type_id = register_type type_ in
    let result_id = gen_id type_ op.result_name in
    push_op (create_value_op op.op type_id result_id) ;
    result_id

  let compile_action_op =
    let open Op.Action in
    function Store (ptr, value) -> push_op (`OpStore (!^ptr, !^value, None))

  let rec compile : type a. a Id.t Dsl.t -> a Id.t = function
    | Declare_function (name, args, vars, return_type, body, continuation) ->
        let id = define_function name args vars return_type body ~f:compile in
        compile (continuation id)
    | Declare_constant (Type.Uint32, value, continuation) ->
        compile @@ continuation
        @@ register_constant Type.Uint32 (Unsigned.UInt32.to_int value)
    | Declare_constant (Type.Bool, value, continuation) ->
        compile @@ continuation
        @@ register_constant Type.Bool (if value then 1 else 0)
    | Declare_constant _ ->
        failwith "Declare_constant: cannot declare non-scalar constants"
    | Call_function (fn, arg_ids, continuation) ->
        let return_type = Type.function_return_type (Id.typ fn) in
        let return_type_id = register_type return_type in
        let return_id = gen_id return_type "fn_return" in
        let arg_id_values = Id.List.(map arg_ids {f= (fun id -> !^id)}) in
        push_op
          (`OpFunctionCall
            (!^return_type_id, !^return_id, !^fn, arg_id_values)) ;
        compile (continuation return_id)
    | Value_op (op, continuation) ->
        compile (continuation (compile_value_op op))
    | Action_op (op, continuation) ->
        compile_action_op op ;
        compile (continuation ())
    | Do_if {cond; then_; after} ->
        let then_label = gen_id Type.Label "if_then" in
        let after_label = gen_id Type.Label "if_after" in
        push_block
          ~branch:
            (Spirv_module.Branch.Conditional
               (!^cond, !^then_label, !^after_label))
          ~next_label:!^then_label ;
        ignore (compile (then_ ())) ;
        push_block ~branch:(Spirv_module.Branch.Unconditional !^after_label)
          ~next_label:!^after_label ;
        compile (after ())
    | If {cond; then_; else_; after} ->
        let then_label = gen_id Type.Label "if_then" in
        let else_label = gen_id Type.Label "if_else" in
        let after_label = gen_id Type.Label "if_after" in
        push_block
          ~branch:
            (Spirv_module.Branch.Conditional
               (!^cond, !^then_label, !^else_label))
          ~next_label:!^then_label ;
        let then_id = compile (then_ ()) in
        push_block ~branch:(Spirv_module.Branch.Unconditional !^after_label)
          ~next_label:!^else_label ;
        let else_id = compile (else_ ()) in
        push_block ~branch:(Spirv_module.Branch.Unconditional !^after_label)
          ~next_label:!^after_label ;
        let type_ = Id.typ then_id in
        let type_id = register_type type_ in
        let phi_id = gen_id type_ "phi" in
        push_op
          (`OpPhi
            ( !^type_id
            , !^phi_id
            , [(!^then_id, !^then_label); (!^else_id, !^else_label)] )) ;
        compile (after phi_id)
    | For {var_ptr; range= low, high; body; after} ->
        let var_type = Type.pointer_elt (Id.typ var_ptr) in
        let var_type_id = register_type var_type in
        let bool_type_id = register_type Type.Bool in
        let const_1 = register_constant var_type 1 in
        let header_label = gen_id Type.Label "loop_header" in
        let merge_label = gen_id Type.Label "loop_merge" in
        let body_label = gen_id Type.Label "loop_body" in
        let continue_label = gen_id Type.Label "loop_continue" in
        let after_label = gen_id Type.Label "loop_after" in
        let var_0 = gen_id var_type "var_0" in
        let var_1 = gen_id var_type "var_1" in
        let cond = gen_id Type.Bool "cond" in
        push_op (`OpStore (!^var_ptr, !^low, None)) ;
        push_block ~branch:(Spirv_module.Branch.Unconditional !^header_label)
          ~next_label:!^header_label ;
        push_op (`OpLoopMerge (!^merge_label, !^continue_label, [])) ;
        push_block ~branch:(Spirv_module.Branch.Unconditional !^merge_label)
          ~next_label:!^merge_label ;
        push_op (`OpLoad (!^var_type_id, !^var_0, !^var_ptr, None)) ;
        push_op (`OpSLessThanEqual (!^bool_type_id, !^cond, !^var_0, !^high)) ;
        push_block
          ~branch:
            (Spirv_module.Branch.Conditional
               (!^cond, !^body_label, !^after_label))
          ~next_label:!^after_label ;
        ignore (compile (body var_0)) ;
        push_block ~branch:(Spirv_module.Branch.Unconditional !^continue_label)
          ~next_label:!^continue_label ;
        push_op (`OpIAdd (!^var_type_id, !^var_1, !^var_0, !^const_1)) ;
        push_op (`OpStore (!^var_ptr, !^var_1, None)) ;
        push_block ~branch:(Spirv_module.Branch.Unconditional !^header_label)
          ~next_label:!^after_label ;
        compile (after ())
    | Set_prefix _ -> failwith "Set_prefix: unimplemented"
    | Pure x -> x
end

let compile dsl out_file =
  let module Compiler = Make_compiler (Make_program ()) in
  ignore (Compiler.compile dsl) ;
  let ops = Spirv_module.compile (Compiler.Program.extract ()) in
  let words = Spirv.compile_to_words ops in
  let ch = Out_channel.create ~binary:true out_file in
  List.iter words ~f:(fun i32 ->
      Out_channel.output_binary_int ch (Batteries.Int32.to_int i32) ) ;
  Out_channel.flush ch ;
  match Unix.system (Printf.sprintf "spirv-val %s" out_file) with
  | Ok () -> ()
  | Error (`Exit_non_zero exit) ->
      failwith
        (Printf.sprintf "compiled spirv failed validation (exit code %d)" exit)
  | Error (`Signal signal) ->
      failwith
        (Printf.sprintf "spirv-val process received unexpected signal (%s)"
           (Signal.to_string signal))
