open Camlp4.PreCast
open Camlp4.PreCast.Ast

let generator_number = 0x0000fadel

let _loc = Loc.ghost

module StringMap = Map.Make(String)

let (<=<) f g x = f (g x)

type spv_type =
  | Id
  | LiteralInteger
  | LiteralContextDependentNumber
  | LiteralExtInstInteger
  | LiteralSpecConstantOpInteger
  | LiteralString
  | Composite of spv_type list
and spv_enumerant_parameter =
  { parameter_kind_raw_name: string;
    parameter_kind_name: string;
    parameter_name: string option;
    parameter_kind: spv_kind option }
and spv_enumerant =
  { enumerant_name: string;
    enumerant_value: string;
    enumerant_capabilities: string list;
    enumerant_parameters: spv_enumerant_parameter list }
and spv_enum_category = Bit | Value
and spv_enum_parameterization = NonParameterized | Parameterized
and spv_enum_type = spv_enum_category * spv_enum_parameterization
and spv_kind = 
  | Type of string * string * spv_type
  | Enum of string * string * spv_enum_type * spv_enumerant list
and spv_operand_quantifier = Optional | Variadic
and spv_operand =
  { operand_kind: spv_kind;
    operand_name: string option;
    quantifier: spv_operand_quantifier option }
and spv_instruction =
  { instruction_name: string;
    instruction_code: int;
    instruction_operands: spv_operand list;
    instruction_capabilities: string list }

type spv_spec_op_constant_info =
  { spec_op_name: string;
    spec_op_operands: spv_operand list;
    spec_op_instruction_code: int }

type spv_info =
  { magic_number: string;
    version: int * int;
    kinds: spv_kind list;
    instructions: spv_instruction list;
    spec_op_constants: spv_spec_op_constant_info list }

module Util = struct
  let mutate_head fn = function
    | h :: t -> (fn h) :: t
    | []     -> failwith "cannot mutate head of empty list"

  let reduce fn = function
    | h1 :: h2 :: t -> List.fold_left fn h1 (h2 :: t)
    | [scalar]      -> failwith "cannot reduce a list of length 1"
    | []            -> failwith "cannot reduce an empty list"

  let rec list_get n = function
    | h :: t -> if n = 0 then h else list_get (n - 1) t
    | []     -> failwith "list_get out of bounds"

  let rec remove_last_el = function
    | [_]    -> []
    | h :: t -> h :: remove_last_el t
    | []     -> failwith "remove_last_el called on empty list"

  let generate_names n =
    let iota n =
      let rec loop i = if i < n then i :: (loop (i + 1)) else [] in
      loop 0
    in
    let string_of_char = String.make 1 in
    let lower_alpha_of_int n = string_of_char @@ Char.chr (n + 97) in
    List.map lower_alpha_of_int (iota n)

  let ocaml_name_of_kind = function
    | Enum (_, n, _, _) -> n
    | Type (_, n, _) -> n

  let rec filter_kinds = function
    | Enum (_, n, ty, e) :: t ->
        let (enums, types) = filter_kinds t in
        ((n, ty, e) :: enums, types)
    | Type (_, n, k) :: t ->
        let (enums, types) = filter_kinds t in
        (enums, (n, k) :: types)
    | [] -> ([], [])

  let snake_case_of_camel_case str =
    let str_len = String.length str in

    let is_uppercase c =
      let v = Char.code c in
      65 <= v && v <= 90
    in

    let string_of_char = String.make 1 in

    let rec loop i =
      if i = str_len then "" else
        let c = String.get str i in
        let replacement =
          if is_uppercase c then
            (if i = 0 then "" else "_") ^ (string_of_char @@ Char.lowercase c)
          else string_of_char c
        in
        replacement ^ loop (i + 1)
    in

    loop 0
end

module Parsing = struct
  open Yojson.Basic.Util

  let cast_spv_kind = function
    | "Id" | "IdRef"                  -> Id
    | "LiteralInteger"                -> LiteralInteger
    | "LiteralContextDependentNumber" -> LiteralContextDependentNumber
    | "LiteralExtInstInteger"         -> LiteralExtInstInteger
    | "LiteralString"                 -> LiteralString
    | "LiteralSpecConstantOpInteger"  -> LiteralSpecConstantOpInteger
    | _ as kind                       -> failwith ("unhandled spv kind: " ^ kind)

  (* this is a hack to reformat OpExtInst's operands to fit the pattern of OpSpecConstantOp *)
  let transform_operands name operands =
    match name with
      | "OpExtInst" -> Util.remove_last_el operands
      | _           -> operands

  let opt_member fn key obj =
    if List.mem key (keys obj) then
      Some (fn @@ member key obj)
    else
      None

  let opt_ls_member key obj =
    if List.mem key (keys obj) then
      to_list @@ member key obj
    else
      []

  (* TODO: add escapes *)
  let format_and_escape_kind_name name = Util.snake_case_of_camel_case name
  let fix_invalid_enumerant_name prefix name =
    let name =
      if Str.string_match (Str.regexp "^[a-z]") name 0 then
        String.capitalize name
      else
        name
    in
    prefix ^ name

  let rec lookup_kind_by_raw_name raw_name = function
    | (Enum (name, _, _, _) as h) :: t
    | (Type (name, _, _) as h) :: t ->
        if name = raw_name then
          h
        else
          lookup_kind_by_raw_name raw_name t
    | [] ->
        failwith "kind not found"

  let cast_operand_quantifier = function
    | "?" -> Optional
    | "*" -> Variadic
    | _   -> failwith "unhandled instruction quantifier"

  let destruct_operand kinds obj =
    let raw_kind_name = to_string @@ member "kind" obj in
    let kind = lookup_kind_by_raw_name raw_kind_name kinds in
    let name = opt_member to_string "name" obj in
    let quantifier = opt_member (cast_operand_quantifier <=< to_string) "quantifier" obj in
    { operand_kind = kind;
      operand_name = name;
      quantifier = quantifier }

  let destruct_instruction kinds obj =
    let name = to_string @@ member "opname" obj in
    let code = to_int @@ member "opcode" obj in
    let filtered_operands_obj = transform_operands name @@ opt_ls_member "operands" obj in
    let operands = List.map (destruct_operand kinds) filtered_operands_obj in
    let capabilities = List.map to_string @@ opt_ls_member "capabilities" obj in
    { instruction_name = name;
      instruction_code = code;
      instruction_operands = operands;
      instruction_capabilities = capabilities }

  let destruct_enumerant_parameter obj =
    let raw_kind_name = to_string @@ member "kind" obj in
    let kind_name = format_and_escape_kind_name raw_kind_name in
    let parameter_name = opt_member to_string "name" obj in
    { parameter_kind_raw_name = raw_kind_name;
      parameter_kind_name = kind_name;
      parameter_name = parameter_name;
      parameter_kind = None }

  let destruct_enumerant enum_type_name value_fn obj =
    let raw_name = to_string @@ member "enumerant" obj in
    let name = fix_invalid_enumerant_name enum_type_name raw_name in
    let value = value_fn @@ member "value" obj in
    let capabilities = List.map to_string @@ opt_ls_member "capabilities" obj in
    let parameters = List.map destruct_enumerant_parameter @@ opt_ls_member "parameters" obj in
    { enumerant_name = name;
      enumerant_value = value;
      enumerant_capabilities = capabilities;
      enumerant_parameters = parameters }

  let destruct_kind obj =
    let raw_kind_name = to_string @@ member "kind" obj in
    let kind_name = format_and_escape_kind_name raw_kind_name in

    let process_enumerants value_conv_fn =
      let raw_enumerants = to_list @@ member "enumerants" obj in
      let destruct = destruct_enumerant raw_kind_name value_conv_fn in
      List.map destruct raw_enumerants
    in

    let process_bases () =
      let kind_names = List.map to_string @@ to_list @@ member "bases" obj in
      List.map cast_spv_kind kind_names
    in

    let enumerant_has_parameters { enumerant_parameters = p } =
      match p with
        | [] -> false
        | _  -> true
    in

    let make_enum ty fn =
      let enumerants = process_enumerants fn in
      let parameterization =
        if List.for_all ((not) <=< enumerant_has_parameters) enumerants
          then NonParameterized else Parameterized
      in
      Enum (raw_kind_name, kind_name, (ty, parameterization), enumerants)
    in

    match to_string @@ member "category" obj with
      | "BitEnum"   -> make_enum Bit to_string
      | "ValueEnum" -> make_enum Value (string_of_int <=< to_int)
      | "Id"        -> Type (raw_kind_name, kind_name, Id)
      | "Literal"   -> Type (raw_kind_name, kind_name, cast_spv_kind raw_kind_name)
      | "Composite" -> Type (raw_kind_name, kind_name, Composite (process_bases ()))
      | _           -> failwith ("unhandled kind category: " ^ raw_kind_name)

  let wire_enum_parameters kinds =
    let replace_parameter param =
      let kind = lookup_kind_by_raw_name param.parameter_kind_raw_name kinds in
      { param with parameter_kind = Some kind }
    in
    let replace_enumerant enumerant =
      let parameters = List.map replace_parameter enumerant.enumerant_parameters in
      { enumerant with enumerant_parameters = parameters }
    in
    let conv_enum = function
      | Enum (rn, n, (ty, Parameterized), enumerants) ->
          let enumerants = List.map replace_enumerant enumerants in
          Enum (rn, n, (ty, Parameterized), enumerants)
      | _ as kind ->
          kind
    in
    List.map conv_enum kinds

  let construct_spec_op_constant_info instructions op_name =
    let rec chomp_result_operands = function
      | { operand_kind = Type ("IdResultType", _, _); _ } :: t
      | { operand_kind = Type ("IdResult", _, _); _ } :: t     ->
          chomp_result_operands t
      | _ as ops -> ops
    in

    let truncated_op_name = String.sub op_name 2 (String.length op_name - 2) in
    let instruction = List.find (fun i -> i.instruction_name = op_name) instructions in
    let operands = chomp_result_operands instruction.instruction_operands in
    { spec_op_name = truncated_op_name;
      spec_op_operands = operands;
      spec_op_instruction_code = instruction.instruction_code }

  let parse core_json supplemental_json =
    let magic_number = to_string @@ member "magic_number" core_json in
    let major_version = to_int @@ member "major_version" core_json in
    let minor_version = to_int @@ member "minor_version" core_json in
    let kind_objs = to_list @@ member "operand_kinds" core_json in
    let instruction_objs = to_list @@ member "instructions" core_json in
    let spec_op_constants = List.map to_string @@ to_list @@ member "spec_op_constants" supplemental_json in
    let spv_kinds = wire_enum_parameters @@ List.map destruct_kind kind_objs in
    let spv_instructions = List.map (destruct_instruction spv_kinds) instruction_objs in
    let spv_spec_op_constants = List.map (construct_spec_op_constant_info spv_instructions) spec_op_constants in
    { magic_number = magic_number;
      version = (major_version, minor_version);
      kinds = spv_kinds;
      instructions = spv_instructions;
      spec_op_constants = spv_spec_op_constants }
end



(* Ast Templates *)

module Templates = struct
  (* Simple Wrappers *)
  let id_lid n = IdLid (_loc, n)
  let id_uid n = IdUid (_loc, n)

  let ty_id id = TyId (_loc, id)
  let pa_id id = PaId (_loc, id)
  let ex_id id = ExId (_loc, id)

  let ty_id_lid = ty_id <=< id_lid
  let ty_id_uid = ty_id <=< id_uid
  let pa_id_lid = pa_id <=< id_lid
  let pa_id_uid = pa_id <=< id_uid
  let ex_id_lid = ex_id <=< id_lid
  let ex_id_uid = ex_id <=< id_uid

  let ty_or a b = TyOr (_loc, a, b)
  let ty_and a b = TyAnd (_loc, a, b)
  let ty_sta a b = TySta (_loc, a, b)
  let ty_app a b = TyApp (_loc, a, b)
  let mc_or a b = McOr (_loc, a, b)
  let pa_app a b = PaApp (_loc, a, b)
  let ex_int n = ExInt (_loc, n)

  let typedef name body = StTyp (_loc, ReRecursive, TyDcl (_loc, name, [], body, []))

  (* Ast Concatenation *)
  let rec join_ast join = function
    | [i]    -> i
    | i :: t -> join i (join_ast join t)
    | []     -> failwith "cannot call join_ast on empty list"
  let join_types = join_ast ty_or
  let apply_types = join_ast ty_app
  let cons_tuple = join_ast ty_and
  let cons_sta = join_ast ty_sta
  let join_match_cases = join_ast mc_or

  let rec apply_pattern base = function
    | h :: t ->
        apply_pattern (PaApp (_loc, base, h)) t
    | []     -> base

  (* Variants *)
  type ocaml_type_variant = string * ctyp option

  let cons_variant cons = function
    | (name, None)         -> cons name
    | (name, Some of_type) -> TyOf (_loc, cons name, of_type)

  let variant = cons_variant ty_id_uid
  let polymorphic_variant = cons_variant (fun n -> TyVrn (_loc, n))

  let variants = join_types <=< List.map variant

  let polymorphic_variants vars =
    let types = List.map polymorphic_variant vars in
    TyVrnEq (_loc, join_types types)

  (* Matching *)
  (* currently only capable of representing variant match cases *)
  type ocaml_variant_type = Variant | LabelVariant
  type ocaml_pattern = string * string list
  type ocaml_match_case = ocaml_pattern * expr

  let match_case variant_type (pattern, exp) =
    let conv_variant = match variant_type with
      | Variant      -> pa_id_uid
      | LabelVariant -> fun v -> PaVrn (_loc, v)
    in
    let pattern_ast = match pattern with
      | (variant, []) -> conv_variant variant
      | (variant, ls) -> apply_pattern (conv_variant variant) (List.map pa_id_lid ls)
    in
    McArr (_loc, pattern_ast, ExNil _loc, exp)

  let match_cases variant_type = function
    | []       -> failwith "cannot call match_patterns on empty list"
    | [scalar] -> match_case variant_type scalar
    | vec      -> join_match_cases (List.map (match_case variant_type) vec)

  let pattern_match exp variant_type cases =
    let patterns = match_cases variant_type cases in
    <:expr< match $exp$ with $patterns$ >>

  (* Expressions *)
  let fn_call name args =
    let rec apply_args prev = function
      | []     -> failwith "cannot call fn_call on empty args list"
      | [e]    -> ExApp (_loc, prev, e)
      | e :: t -> apply_args (ExApp (_loc, prev, e)) t
    in
    apply_args (ex_id_uid name) args

  let monadic_fn_call name arg = fn_call name [arg]

  let cons head tail = <:expr< $head$ :: $tail$ >>
  let concat_ls_exps a b = <:expr< $a$ @ $b$ >>

  let rec ls_exp = function
    | h :: t ->
        ExApp (_loc,
          ExApp (_loc,
            ExId (_loc, IdUid (_loc, "::")),
            h),
          ls_exp t)
    | []     ->
        ExId (_loc, IdUid (_loc, "[]"))

  (* Scalable List Constructors *)

  (* constructs a scalar or type application from a list of strings *)
  let type_app_of_ls = function
    | []       -> failwith "cannot call type_app_of_ls on empty list"
    | [scalar] -> ty_id_lid scalar
    | vec      -> apply_types (List.map ty_id_lid vec)

  (* constructs a scalar or tuple type from a list of type asts *)
  let type_tuple_of_ls = function
    | []       -> failwith "cannot call type_tuple_of_ls on empty list"
    | [scalar] -> scalar
    | vec      -> cons_tuple vec

  (* constructs a scalar or static tuple type from a list of type asts *)
  let type_sta_tuple_of_ls = function
    | []       -> failwith "cannot call type_sta_tuple_of_ls on empty list"
    | [scalar] -> scalar
    | vec      -> TyTup (_loc, cons_sta vec)
end

type list_or_sca = List | Scalar
type words_exp = list_or_sca * expr

let rec ocaml_types_of_spv_type = function
  | Id                            -> ["id"]
  | LiteralInteger                -> ["int32"]
  | LiteralContextDependentNumber -> ["big_int_or_float"]
  | LiteralExtInstInteger         -> ["ext_inst_fn"] (* TODO *)
  | LiteralSpecConstantOpInteger  -> ["spec_op"]
  | LiteralString                 -> ["string"]
  | Composite ls                  -> List.concat @@ List.map ocaml_types_of_spv_type ls

(* TODO: add missing cases *)
let exp_type_of_kind = function
  | Type (_, _, LiteralContextDependentNumber)
  | Type (_, _, LiteralExtInstInteger)
  | Type (_, _, LiteralSpecConstantOpInteger)
  | Type (_, _, LiteralString)
  | Type (_, _, Composite _)
  | Enum (_, _, (_, Parameterized), _)         -> List
  | _                                          -> Scalar

(* This function currently makes some assumptions about how the one-off kinds are used:
 *   assumption 1: operands are named 'a' - 'z' (currently true in the compiler)
 *   assumption 2: LiteralContextDependentNumber is only in instructions which have a result type as the first operand
 *)
let conversion_fn_of_kind = function
  | Type (_, _, Id)                            -> <:expr< word_of_id >>
  | Type (_, _, LiteralInteger)                -> <:expr< word_of_int >>
  | Type (_, _, LiteralContextDependentNumber) -> <:expr< words_of_context_dependent_number (lookup_size a) >>
  | Type (_, _, LiteralExtInstInteger)         -> <:expr< fun f -> f () >>
  | Type (_, _, LiteralSpecConstantOpInteger)  -> <:expr< words_of_spec_op >>
  | Type (_, _, LiteralString)                 -> <:expr< words_of_string >>
  | Type (_, name, Composite _)
  | Enum (_, name, (_, Parameterized),  _)     -> let fn = "words_of_" ^ name in <:expr< $lid:fn$ >>
  | Enum (_, name, (_, NonParameterized),  _)  -> let fn = "word_of_" ^ name in <:expr< $lid:fn$ >>

let build_kind_typedef (name, t) =
  let type_name = ocaml_types_of_spv_type t in
  let tuple = Templates.type_sta_tuple_of_ls @@ List.map Templates.ty_id_lid type_name in
  Templates.typedef name tuple

let type_list_of_kind_and_quantifier kind quantifier =
  let type_prefix_of_quantifier = function
    | Some Optional -> ["option"]
    | Some Variadic -> ["list"]
    | None          -> []
  in

  let type_prefix_of_kind = function
    | Enum (_, _, (Bit, _), _) -> ["list"]
    | _                        -> []
  in

  let quantifier_prefix = type_prefix_of_quantifier quantifier in
  let kind_prefix = type_prefix_of_kind kind in
  quantifier_prefix @ kind_prefix @ [Util.ocaml_name_of_kind kind]

let build_enum_typedef (name, _, enumerants) =
  let list_of_parameter = function
    | { parameter_kind = Some kind; _ } -> type_list_of_kind_and_quantifier kind None
    | _                                 -> failwith "impossible case"
  in
  let type_tuple_of_parameters params =
    params
      |> List.map list_of_parameter
      |> List.map Templates.type_app_of_ls
      |> Templates.type_tuple_of_ls
  in
  let convert_parameters = function
    | []     -> None
    | _ as p -> Some (type_tuple_of_parameters p)
  in
  let convert_variant enum = (enum.enumerant_name, convert_parameters enum.enumerant_parameters) in
  let variants = Templates.variants @@ List.map convert_variant enumerants in
  Templates.typedef name variants

let type_tuple_of_operands operands = 
  let list_of_operand op = type_list_of_kind_and_quantifier op.operand_kind op.quantifier in

  operands
    |> List.map list_of_operand
    |> List.map Templates.type_app_of_ls
    |> Templates.type_tuple_of_ls

let build_operands_type_opt = function
  | []       -> None
  | operands -> Some (type_tuple_of_operands operands)

let build_op_typedef instructions =
  let cons_variant i = (i.instruction_name, build_operands_type_opt i.instruction_operands) in
  let variants = Templates.polymorphic_variants @@ List.map cons_variant instructions in
  Templates.typedef "op" variants

let build_spec_op_typedef spec_ops =
  let cons_variant so = (so.spec_op_name, build_operands_type_opt so.spec_op_operands) in
  let variants = Templates.polymorphic_variants @@ List.map cons_variant spec_ops in
  Templates.typedef "spec_op" variants

let words_exp_of_operand (op, binding) =
  let { operand_kind = kind; quantifier = quantifier; _ } = op in
  let exp_type = exp_type_of_kind kind in
  let conversion_fn = conversion_fn_of_kind kind in
  match (exp_type, quantifier) with
    | (Scalar, Some Optional) ->
        (List, <:expr< list_of_option (apply_option $conversion_fn$ $binding$) >>)
    | (List, Some Optional)   ->
        (List, <:expr< list_of_list_option (apply_option $conversion_fn$ $binding$) >>)
    | (Scalar, Some Variadic) ->
        (List, <:expr< List.map $conversion_fn$ $binding$ >>)
    | (List, Some Variadic)   ->
        (List, <:expr< List.concat (List.map $conversion_fn$ $binding$) >>)
    | (_, None)               ->
        (exp_type, <:expr< $conversion_fn$ $binding$ >>)

let concat_words_exps words_exps =
  let empty_ls_exp = Templates.ex_id_uid "[]" in
  let rec join_words_exps = function
    | (Scalar, e) :: t ->
        let (was_scalar, ls) = join_words_exps t in
        let new_ls = if was_scalar then
          Util.mutate_head (Templates.cons e) ls
        else
          (Templates.cons e empty_ls_exp) :: ls
        in
        (true, new_ls)
    | (List, e) :: t   ->
        let (_, ls) = join_words_exps t in
        (false, e :: ls)
    | []               ->
        (false, [])
  in
  let (_, ls) = join_words_exps words_exps in
  match ls with
    | [e] -> e
    | _   -> Util.reduce Templates.concat_ls_exps ls

let id_exp_of_instruction bindings = function
  | _ :: ({ operand_kind = Type ("IdResult", _, _); _ } :: _) ->
      let binding = Util.list_get 1 bindings in
      <:expr< Some $binding$ >>
  | _                                            ->
      <:expr< None >>

let map_exp_of_instruction bindings = function
  | "OpTypeInt"
  | "OpTypeFloat" ->
      let id = Util.list_get 0 bindings in
      let value = Util.list_get 1 bindings in
      <:expr< IdMap.add $id$ (Int32.to_int $value$) size_map >>
  | "OpConstant"  ->
      let result_type = Util.list_get 0 bindings in
      let id = Util.list_get 1 bindings in
      <:expr< IdMap.add $id$ (IdMap.find $result_type$ size_map) size_map >>
  | _             ->
      <:expr< size_map >>

let build_words_exp_of_instruction instruction operand_names =
  let code_exp = Templates.ex_int @@ (Printf.sprintf "0x%04xl" instruction.instruction_code) in
  let operand_bindings = List.map Templates.ex_id_lid operand_names in
  let operand_words_exps = List.map words_exp_of_operand @@ List.combine instruction.instruction_operands operand_bindings in
  let operand_words_exp = 
    if List.length operand_words_exps > 0 then
      concat_words_exps operand_words_exps
    else
      <:expr< [] >>
  in
  let map_exp = map_exp_of_instruction operand_bindings instruction.instruction_name in
  let id_exp = id_exp_of_instruction operand_bindings instruction.instruction_operands in
  <:expr< ($map_exp$, $id_exp$, build_op_words $code_exp$ $operand_words_exp$) >>

let build_words_of_op_fn instructions =
  let match_case_of_instruction instruction =
    let operand_names = Util.generate_names (List.length instruction.instruction_operands) in
    let exp = build_words_exp_of_instruction instruction operand_names in
    ((instruction.instruction_name, operand_names), exp)
  in

  let patterns = Templates.match_cases Templates.LabelVariant @@ List.map match_case_of_instruction instructions in

  <:str_item<
    let rec words_and_id_of_op : int IdMap.t -> op -> int IdMap.t * id option * word list = fun size_map op ->
      let lookup_size = fun (id : id) ->
        if IdMap.mem id size_map then
          IdMap.find id size_map
        else
          let print_ids k _ = print_endline @@ Int32.to_string k in
          (IdMap.iter print_ids size_map; raise (Id_not_found id))
      in
      let build_op_words = fun code operand_words ->
        let shifted_word_count = (List.length operand_words + 1) lsl 16 in
        Int32.logor code (Int32.of_int shifted_word_count) :: operand_words
      in
      match op with $patterns$
  >>

let build_words_of_spec_op_fn spec_ops =
  let match_case_of_spec_op spec_op =
    let code_exp = Templates.ex_int @@ (Printf.sprintf "0x%04xl" spec_op.spec_op_instruction_code) in
    let operand_names = Util.generate_names (List.length spec_op.spec_op_operands) in
    let operand_bindings = List.map Templates.ex_id_lid operand_names in
    let operand_words_exps = List.map words_exp_of_operand @@ List.combine spec_op.spec_op_operands operand_bindings in
    let operand_words_exp = 
      if List.length operand_words_exps > 0 then
        let exp = concat_words_exps operand_words_exps in
        <:expr< $code_exp$ :: $exp$ >>
      else
        <:expr< [$code_exp$] >>
    in
    ((spec_op.spec_op_name, operand_names), operand_words_exp)
  in

  let patterns = Templates.match_cases Templates.LabelVariant @@ List.map match_case_of_spec_op spec_ops in

  <:str_item<
    let rec words_of_spec_op : spec_op -> word list = fun spec_op ->
      match spec_op with $patterns$
  >>

let words_exp_of_enumerant_parameter (param, binding) =
  match param.parameter_kind with
    | None      -> failwith "enumerant parameter has unkown kind"
    | Some kind ->
        let conversion_fn = conversion_fn_of_kind kind in
        (exp_type_of_kind kind, <:expr< $conversion_fn$ $binding$ >>)

let build_words_exp_of_parameterized_enumerant enumerant parameter_names =
  let parameter_bindings = List.map Templates.ex_id_lid parameter_names in
  let parameter_words_exps = List.map words_exp_of_enumerant_parameter @@ List.combine enumerant.enumerant_parameters parameter_bindings in
  concat_words_exps parameter_words_exps

(* TODO: refactor *)
let build_enum_value_fn (name, (ty, parameterization), enumerants) =
  let match_case_of_enumerant enum =
    let
      { enumerant_name = name;
        enumerant_value = value;
        enumerant_parameters = params }
          = enum
    in
    let value_exp = Templates.ex_int (value ^ "l") in
    match (parameterization, params) with
      | (NonParameterized, [])  -> ((name, []), value_exp)
      | (Parameterized, [])     -> ((name, []), Templates.ls_exp [value_exp])
      | (Parameterized, params) ->
          let param_names = Util.generate_names (List.length params) in
          let word_exps = build_words_exp_of_parameterized_enumerant enum param_names in
          ((name, param_names), <:expr< $value_exp$ :: $word_exps$ >>)
      | _                       -> failwith "impossible case"
  in

  let split_match_case_of_enumerant enum =
    let
      { enumerant_name = name;
        enumerant_value = value;
        enumerant_parameters = params }
          = enum
    in
    let value_exp = Templates.ex_int (value ^ "l") in
    let param_names = Util.generate_names (List.length params) in
    let operands_exp = match params with
      | []     -> <:expr< [] >>
      | params -> build_words_exp_of_parameterized_enumerant enum param_names
    in
    ((name, param_names), <:expr< ($value_exp$, $operands_exp$) >>)
  in

  let fn_name = match parameterization with
    | NonParameterized -> "word_of_" ^ name 
    | Parameterized    -> "words_of_" ^ name
  in

  let name_id = Templates.ty_id_lid name in
  let fn_name_id = Templates.pa_id_lid fn_name in

  match (ty, parameterization) with
    | (Value, _) ->
        let patterns = Templates.match_cases Templates.Variant @@ List.map match_case_of_enumerant enumerants in
        <:str_item<
          let $fn_name_id$ = fun (enum : $name_id$) ->
            match enum with $patterns$
        >>
    | (Bit, NonParameterized) ->
        let patterns = Templates.match_cases Templates.Variant @@ List.map match_case_of_enumerant enumerants in
        <:str_item<
          let $fn_name_id$ = fun (flags : $name_id$ list) ->
            let flag_value flag = match flag with $patterns$ in
            let fold_flag base flag = Int32.logor base (flag_value flag) in
            List.fold_left fold_flag 0l flags
        >>
    | (Bit, Parameterized) ->
        let split_patterns = Templates.match_cases Templates.Variant @@ List.map split_match_case_of_enumerant enumerants in
        <:str_item<
          let $fn_name_id$ = fun (flags : $name_id$ list) ->
            let split flag = match flag with $split_patterns$ in
            let combine_split_flags (a_flag, a_ops) (b_flag, b_ops) =
              (Int32.logor a_flag b_flag, a_ops @ b_ops)
            in
            let (flag, ops) = List.fold_left combine_split_flags (0l, []) (List.map split flags) in
            flag :: ops
        >>

module StaticElements = struct
  let open_definitions = [ <:str_item< open Batteries >> ]

  let module_definitions = [
    <:str_item< module IdMap = Map.Make(Int32) >>
  ]

  let module_signatures = [
    <:sig_item< module IdMap : Map.S with type key = Int32.t >>
  ]

  let exception_definitions = [
    <:str_item< exception Id_not_found of Int32.t >>
  ]

  let type_definitions = [
    <:str_item< type id = int32 >>;
    <:str_item< type word = int32 >>;
    <:str_item< type big_int = Big_int.big_int >>;
    <:str_item< type big_int_or_float = BigInt of big_int | Float of float >>;
    <:str_item< type ext_inst_fn = unit -> word list >>
  ]

  (* TODO: generate these *)
  let lazy_definitions = [
    <:str_item<
      let words_of_pair_literal_integer_id_ref = fun (n, i) -> [word_of_int n; word_of_id i]
    >>;
    <:str_item<
      let words_of_pair_id_ref_literal_integer = fun (i, n) -> [word_of_id i; word_of_int n]
    >>;
    <:str_item<
      let words_of_pair_id_ref_id_ref = fun (a, b) -> [word_of_id a; word_of_id b]
    >>
  ]

  let conversion_functions = [
    (* TODO: remove unecessary conversion functions *)
    <:str_item<
      let word_of_int = fun (i : int32) -> i
    >>;
    <:str_item<
      let word_of_id = fun (id : id) -> 
        if id < 0l then
          failwith "spirv ids must be positive"
        else
          id
    >>;
    <:str_item<
      let word_of_float = fun (f : float) ->
        let open IO in
        let buf = output_string () in
        write_float buf f;
        let str = close_out buf in
        let rec write_to_int32 = fun n acc ls ->
          match ls with
            | h :: t ->
                let value = Int32.of_int @@ Char.code h in
                let acc = Int32.logor acc (Int32.shift_left value (8 * n)) in
                write_to_int32 (n + 1) acc t
            | []     -> acc
        in
        write_to_int32 0 0l (String.to_list str) 
    >>;
    <:str_item<
    >>;
    <:str_item<
      let words_of_context_dependent_number = fun (size : int) (value : big_int_or_float) ->
        let word_size = 32 in
        let words_of_sized_big_int n =
          let round_up_divisible divisor n =
            (n / divisor) + (if n mod divisor > 0 then 1 else 0)
          in
          let word_count = round_up_divisible word_size size in
          let extract_word i = Int32.of_int @@ Big_int.int_of_big_int @@ Big_int.extract_big_int n (32 * i) 32 in
          let rec extract_words i =
            if i < word_count then
              extract_word i :: extract_words (i + 1)
            else
              []
          in
          extract_words 0
        in
        match value with
          | BigInt n -> words_of_sized_big_int n
          | Float f  -> if size = 32 then [word_of_float f] else raise (Invalid_argument "cannot write float literals of sizes other than 32 bits")
    >>;
    <:str_item<
      let words_of_string = fun (str : string) ->
        let len = String.length str in
        let word_count = (len / 4) + (if len mod 4 >= 0 then 1 else 0) in
        let buffer = Array.make word_count 0l in
        let add_char_to_word ch offset word =
          Int32.logor word (Int32.shift_left (Int32.of_int @@ Char.code ch) (offset * 8))
        in
        let rec add_char_to_buffer i =
          if i = len then
            ()
          else begin
            buffer.(i / 4) <- add_char_to_word (String.get str i) (abs @@ (i mod 4) - 3) buffer.(i / 4);
            add_char_to_buffer (i + 1)
          end
        in
        add_char_to_buffer 0;
        Array.to_list buffer
    >>;
    (* These need to be outside of the words_of_op
     * fn even though they are used only by it.
     * If they are in the function, the type inference
     * breaks on them.
     * TODO: file bug report
     *)
    <:str_item<
      let list_of_option = fun (opt : 'a option) ->
        match opt with
          | Some v -> [v]
          | None   -> []
    >>;
    <:str_item<
      let list_of_list_option = fun (opt : 'a list option) ->
        match opt with
          | Some v -> v
          | None   -> []
    >>;
    <:str_item<
      let apply_option = fun (fn : 'a -> 'b) (opt : 'a option) ->
        match opt with
          | Some v -> Some (fn v)
          | None   -> None
    >>
  ]

  let interfaces = [
    <:str_item<
      let compile_to_words = fun ops ->
        let rec loop = fun map ls ->
          match ls with
            | []     -> (0l, [])
            | op :: t ->
                let (map, id_opt, words) = words_and_id_of_op map op in
                let id = match id_opt with Some i -> i | None -> 0l in
                let (next_id, next_words) = loop map t in
                (max id next_id, words @ next_words)
        in
        let (max_id, op_words) = loop IdMap.empty ops in
        let header = [
          magic_number;
          version_word;
          generator_number;
          Int32.add max_id 1l;
          0l
        ] in

        header @ op_words
    >>
  ]

  let vals = [
    <:sig_item<
      val version : int * int
    >>;
    <:sig_item<
      val compile_to_words : op list -> word list
    >>
  ]
end

(* this is a dumb hack to fix the order of spirv.core.grammar.json *)
let defer_decoration_enum enums =
  let is_decoration (n, _, _) = (n = "decoration") in
  let decoration_def = List.find is_decoration enums in
  List.filter ((not) <=< is_decoration) enums @ [decoration_def]

let pack_version (major, minor) =
  let open Int32 in
  let major_i32 = of_int major in
  let minor_i32 = of_int minor in
  let major_mask = shift_left (logand major_i32 0x03l) 16 in
  let minor_mask = shift_left (logand minor_i32 0x03l) 8 in
  logor major_mask minor_mask

let st_typ x = StTyp (_loc, ReRecursive, x)
let sg_typ x = SgTyp (_loc, ReRecursive, x)

let join_typedefs typedefs wrapper =
  let rec cons_typedefs = function
    | [StTyp (_, _, dcl)]    -> dcl
    | StTyp (_, _, dcl) :: t -> TyAnd (_loc, dcl, cons_typedefs t)
    | []     -> failwith "cannot join_typedefs on empty list"
    | _      -> failwith "non typedef str_item in join_typedefs"
  in
  wrapper @@ cons_typedefs typedefs

let generate_implementation output info =
  let (enums, types) = Util.filter_kinds info.kinds in
  let enums = defer_decoration_enum enums in

  List.iter output StaticElements.open_definitions;
  List.iter output StaticElements.module_definitions;
  List.iter output StaticElements.exception_definitions;

  (* typedefs *)
  let typedefs =
    StaticElements.type_definitions @
    List.map build_kind_typedef types @
    List.map build_enum_typedef enums @
    [
      build_op_typedef info.instructions;
      build_spec_op_typedef info.spec_op_constants
    ]
  in

  output @@ join_typedefs typedefs st_typ;

  (* values *)
  let magic_number_exp = Templates.ex_int (info.magic_number ^ "l") in
  output <:str_item< let magic_number = $magic_number_exp$ >>;

  let (major_version, minor_version) = info.version in
  let major_version_exp = Templates.ex_int (string_of_int major_version) in
  let minor_version_exp = Templates.ex_int (string_of_int minor_version) in
  output <:str_item< let version = ($major_version_exp$, $minor_version_exp$) >>;

  let packed_version_exp = Templates.ex_int @@ Printf.sprintf "0x%08lxl" (pack_version info.version) in
  output <:str_item< let version_word = $packed_version_exp$ >>;

  let generator_number_exp = Templates.ex_int @@ (Printf.sprintf "0x%04lxl" generator_number) in
  output <:str_item< let generator_number = $generator_number_exp$ >>;

  (* functions *)
  List.iter output StaticElements.conversion_functions;
  List.iter output StaticElements.lazy_definitions;
  List.iter output @@ List.map build_enum_value_fn enums;
  output @@ build_words_of_spec_op_fn info.spec_op_constants;
  output @@ build_words_of_op_fn info.instructions;
  List.iter output StaticElements.interfaces

let cast_sig = function
  | StTyp (loc, re, t)    -> SgTyp (loc, re, t)
  | StOpn (loc, ov, i)    -> SgOpn (loc, ov, i)
  | StExc (loc, t, _) -> SgExc (loc, t)
  | _              -> failwith "unhandled case in cast_sig"

let generate_interface output info =
  let (enums, types) = Util.filter_kinds info.kinds in
  let enums = defer_decoration_enum enums in

  List.iter output @@ List.map cast_sig StaticElements.open_definitions;
  List.iter output @@ StaticElements.module_signatures;
  List.iter output @@ List.map cast_sig StaticElements.exception_definitions;

  (* typedefs *)
  let typedefs =
    StaticElements.type_definitions @
    List.map build_kind_typedef types @
    List.map build_enum_typedef enums @
    [
      build_op_typedef info.instructions;
      build_spec_op_typedef info.spec_op_constants
    ]
  in

  output @@ join_typedefs typedefs sg_typ;

  List.iter output StaticElements.vals

let () =
  (if Array.length Sys.argv < 2 then failwith "Invalid number of arguments");

  let generator = match Sys.argv.(1) with
    | "implem" -> generate_implementation Printers.OCaml.print_implem
    | "interf" -> generate_interface Printers.OCaml.print_interf
    | _        -> failwith "Invalid argument"
  in

  let core_grammar_ch = open_in "spirv.core.grammar.json" in
  let supplemental_data_ch = open_in "spirv.supplemental.json" in
  let core_grammar_json = Yojson.Basic.from_channel core_grammar_ch in
  let supplemental_data_json = Yojson.Basic.from_channel supplemental_data_ch in
  let spirv_info = Parsing.parse core_grammar_json supplemental_data_json in
  close_in supplemental_data_ch;
  close_in core_grammar_ch;

  generator spirv_info
