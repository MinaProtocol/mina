open Core

module Capability = struct
  type t = SpirV.capability

  let to_op t : SpirV.op = `OpCapability t
end

module Memory_model = struct
  type t = SpirV.addressing_model * SpirV.memory_model

  let to_op (addr_model, mem_model) : SpirV.op =
    `OpMemoryModel (addr_model, mem_model)
end

module Entry_point = struct
  type t =
    { execution_mode: SpirV.execution_mode
    ; execution_model: SpirV.execution_model
    ; id: SpirV.id
    ; name: string
    ; interfaces: SpirV.id list }

  let to_entry_point_op t : SpirV.op =
    `OpEntryPoint (t.execution_model, t.id, t.name, t.interfaces)

  let to_execution_mode_op t : SpirV.op =
    `OpExecutionMode (t.id, t.execution_mode)
end

module Decoration = struct
  type t =
    | Decoration of {target: SpirV.id; value: SpirV.decoration}
    | MemberDecoration of
        { target: SpirV.id
        ; member: SpirV.literal_integer
        ; value: SpirV.decoration }

  let to_op : t -> SpirV.op = function
    | Decoration d -> `OpDecorate (d.target, d.value)
    | MemberDecoration d -> `OpMemberDecorate (d.target, d.member, d.value)
end

module Type = struct
  type t =
    | Void
    | Bool
    | Int of SpirV.literal_integer * bool
    | Float of SpirV.literal_integer
    | Vector of SpirV.id * SpirV.literal_integer
    | RuntimeArray of SpirV.id
    | Struct of SpirV.id list
    | Pointer of SpirV.storage_class * SpirV.id
    | Function of SpirV.id * SpirV.id list

  let to_op id : t -> SpirV.op = function
    | Void -> `OpTypeVoid id
    | Bool -> `OpTypeBool id
    | Int (width, sign) -> `OpTypeInt (id, width, if sign then 1l else 0l)
    | Float width -> `OpTypeFloat (id, width)
    | Vector (t, size) -> `OpTypeVector (id, t, size)
    | RuntimeArray t -> `OpTypeRuntimeArray (id, t)
    | Struct ts -> `OpTypeStruct (id, ts)
    | Pointer (sc, t) -> `OpTypePointer (id, sc, t)
    | Function (rt, ats) -> `OpTypeFunction (id, rt, ats)
end

module Type_declaration = struct
  type t = {id: SpirV.id; value: Type.t}

  let to_op t : SpirV.op = Type.to_op t.id t.value
end

module Constant_declaration = struct
  type t = {type_: SpirV.id; id: SpirV.id; value: SpirV.big_int_or_float}

  let to_op t : SpirV.op = `OpConstant (t.type_, t.id, t.value)
end

module Variable_declaration = struct
  type t =
    { type_: SpirV.id
    ; id: SpirV.id
    ; storage_class: SpirV.storage_class
    ; initializer_: SpirV.id option }

  let to_op t : SpirV.op =
    `OpVariable (t.type_, t.id, t.storage_class, t.initializer_)
end

module Branch = struct
  type t =
    | Unconditional of SpirV.id
    | Conditional of SpirV.id * SpirV.id * SpirV.id
    | Return
    | ReturnValue of SpirV.id

  let to_op : t -> SpirV.op = function
    | Unconditional label -> `OpBranch label
    | Conditional (cond, true_label, f_label) ->
        `OpBranchConditional (cond, true_label, f_label, [])
    | Return -> `OpReturn
    | ReturnValue v -> `OpReturnValue v
end

module Basic_block = struct
  type t = {label: SpirV.id; body: SpirV.op list; branch: Branch.t}

  let to_ops t : SpirV.op list =
    List.concat [[`OpLabel t.label]; t.body; [Branch.to_op t.branch]]
end

module Function_parameter = struct
  type t = {type_: SpirV.id; id: SpirV.id}

  let to_op t : SpirV.op = `OpFunctionParameter (t.type_, t.id)
end

module Function_definition = struct
  type t =
    { return_type: SpirV.id
    ; id: SpirV.id
    ; control: SpirV.function_control list
    ; type_: SpirV.id
    ; parameters: Function_parameter.t list
    ; variables: Variable_declaration.t list
    ; body: Basic_block.t list }

  let to_ops t : SpirV.op list =
    List.concat
      [ [`OpFunction (t.return_type, t.id, t.control, t.type_)]
      ; List.map t.parameters ~f:Function_parameter.to_op
      ; List.map t.variables ~f:Variable_declaration.to_op
      ; List.concat (List.map t.body ~f:Basic_block.to_ops)
      ; [`OpFunctionEnd] ]
end

type t =
  { capabilities: Capability.t list
  ; memory_model: Memory_model.t
  ; entry_points: Entry_point.t list (* ;  debug_info: debug_info list *)
  ; decorations: Decoration.t list
  ; types: Type_declaration.t list
  ; constants: Constant_declaration.t list
  ; global_variables: Variable_declaration.t list
  ; functions: Function_definition.t list }

let compile t : SpirV.op list =
  List.concat
    [ List.map t.capabilities ~f:Capability.to_op
    ; [Memory_model.to_op t.memory_model]
    ; List.map t.entry_points ~f:Entry_point.to_entry_point_op
    ; List.map t.entry_points ~f:Entry_point.to_execution_mode_op
    ; List.map t.decorations ~f:Decoration.to_op
    ; List.map t.types ~f:Type_declaration.to_op
    ; List.map t.constants ~f:Constant_declaration.to_op
    ; List.map t.global_variables ~f:Variable_declaration.to_op
    ; List.concat (List.map t.functions ~f:Function_definition.to_ops) ]
