open Core

type capability = SpirV.capability
let compile_capability_op (c : capability) : SpirV.op = `OpCapability c

type memory_model = SpirV.addressing_model * SpirV.memory_model
let compile_memory_model_op ((addr_model, mem_model) : memory_model) : SpirV.op =
  `OpMemoryModel (addr_model, mem_model)

type entry_point =
  { entry_point_execution_mode: SpirV.execution_mode
  ; entry_point_execution_model: SpirV.execution_model
  ; entry_point_id: SpirV.id
  ; entry_point_name: string
  ; entry_point_interfaces: SpirV.id list }
let compile_entry_point_op (ep : entry_point) : SpirV.op =
  `OpEntryPoint
    ( ep.entry_point_execution_model
    , ep.entry_point_id
    , ep.entry_point_name
    , ep.entry_point_interfaces )
let compile_execution_mode_op (ep : entry_point) : SpirV.op =
  `OpExecutionMode
    ( ep.entry_point_id,
      ep.entry_point_execution_mode )

type decoration =
  | Decoration of
      { decoration_target: SpirV.id
      ; decoration_value: SpirV.decoration }
  | MemberDecoration of
      { member_decoration_target: SpirV.id
      ; member_decoration_member: SpirV.literal_integer
      ; member_decoration_value: SpirV.decoration }
let compile_decoration_op : decoration -> SpirV.op = function
  | Decoration d ->
      `OpDecorate
        ( d.decoration_target
        , d.decoration_value )
  | MemberDecoration d ->
      `OpMemberDecorate
        ( d.member_decoration_target
        , d.member_decoration_member
        , d.member_decoration_value )

type spirv_type =
  | TypeVoid
  | TypeBool
  | TypeInt of SpirV.literal_integer * bool
  | TypeFloat of SpirV.literal_integer
  | TypeVector of SpirV.id * SpirV.literal_integer
  | TypeRuntimeArray of SpirV.id
  | TypeStruct of SpirV.id list
  | TypePointer of SpirV.storage_class * SpirV.id
  | TypeFunction of SpirV.id * SpirV.id list
let compile_spirv_type_op (id : SpirV.id) : spirv_type -> SpirV.op = function
  | TypeVoid               -> `OpTypeVoid id
  | TypeBool               -> `OpTypeBool id
  | TypeInt (width, sign)  -> `OpTypeInt (id, width, if sign then 1l else 0l)
  | TypeFloat width        -> `OpTypeFloat (id, width)
  | TypeVector (t, size)   -> `OpTypeVector (id, t, size)
  | TypeRuntimeArray t     -> `OpTypeRuntimeArray (id, t)
  | TypeStruct ts          -> `OpTypeStruct (id, ts)
  | TypePointer (sc, t)    -> `OpTypePointer (id, sc, t)
  | TypeFunction (rt, ats) -> `OpTypeFunction (id, rt, ats)
type type_declaration =
  { type_id: SpirV.id
  ; type_value: spirv_type }
let compile_type_declaration_op (td : type_declaration) : SpirV.op =
  compile_spirv_type_op td.type_id td.type_value

type constant_declaration =
  { constant_type: SpirV.id
  ; constant_id: SpirV.id
  ; constant_value: SpirV.big_int_or_float }
let compile_constant_declaration_op (c : constant_declaration) : SpirV.op =
  `OpConstant (c.constant_type, c.constant_id, c.constant_value)

type variable_declaration =
  { variable_type: SpirV.id
  ; variable_id: SpirV.id
  ; variable_storage_class: SpirV.storage_class
  ; variable_initializer: SpirV.id option }
let compile_variable_declaration_op (v : variable_declaration) : SpirV.op =
  `OpVariable
    ( v.variable_type
    , v.variable_id
    , v.variable_storage_class
    , v.variable_initializer )

type branch =
  | Branch of SpirV.id
  | BranchConditional of SpirV.id * SpirV.id * SpirV.id
  | Return
  | ReturnValue of SpirV.id
let compile_branch_op : branch -> SpirV.op = function
  | Branch label                                  ->
      `OpBranch label
  | BranchConditional (cond, true_label, f_label) ->
      `OpBranchConditional (cond, true_label, f_label, [])
  | Return ->
      `OpReturn
  | ReturnValue v ->
      `OpReturnValue v

type basic_block =
  { basic_block_label: SpirV.id
  ; basic_block_body: SpirV.op list
  ; basic_block_branch: branch }
let compile_basic_block_ops (block : basic_block) : SpirV.op list =
  List.concat
    [ [`OpLabel block.basic_block_label]
    ; block.basic_block_body
    ; [compile_branch_op block.basic_block_branch]]

type function_parameter =
  { function_parameter_type: SpirV.id
  ; function_parameter_id: SpirV.id }
let compile_function_parameter_op (fp : function_parameter) : SpirV.op =
  `OpFunctionParameter
    ( fp.function_parameter_type
    , fp.function_parameter_id )

type function_definition =
  { function_return_type: SpirV.id
  ; function_id: SpirV.id
  ; function_control: SpirV.function_control list
  ; function_type: SpirV.id
  ; function_parameters: function_parameter list
  ; function_variables: variable_declaration list
  ; function_body: basic_block list }
let compile_function_header_op (fn_def : function_definition) : SpirV.op =
  `OpFunction
    ( fn_def.function_return_type
    , fn_def.function_id
    , fn_def.function_control
    , fn_def.function_type )
let compile_function_definition_ops (fn_def : function_definition) : SpirV.op list =
  List.concat
    [ [compile_function_header_op fn_def]
    ; List.map fn_def.function_parameters ~f:compile_function_parameter_op
    ; List.map fn_def.function_variables ~f:compile_variable_declaration_op
    ; List.concat (List.map fn_def.function_body ~f:compile_basic_block_ops)
    ; [`OpFunctionEnd] ]

type t =
  { capabilities: SpirV.capability list
  ; memory_model: memory_model
  ; entry_points: entry_point list
  (* ;  debug_info: debug_info list *)
  ; decorations: decoration list
  ; types: type_declaration list
  ; constants: constant_declaration list
  ; global_variables: variable_declaration list
  ; functions: function_definition list }
let compile (m : t) : SpirV.op list =
  List.concat
    [ List.map m.capabilities ~f:compile_capability_op
    ; [compile_memory_model_op m.memory_model]
    ; List.map m.entry_points ~f:compile_entry_point_op
    ; List.map m.entry_points ~f:compile_execution_mode_op
    ; List.map m.decorations ~f:compile_decoration_op
    ; List.map m.types ~f:compile_type_declaration_op
    ; List.map m.constants ~f:compile_constant_declaration_op
    ; List.map m.global_variables ~f:compile_variable_declaration_op
    ; List.concat (List.map m.functions ~f:compile_function_definition_ops) ]
