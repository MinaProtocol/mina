open Core
open Unsigned
open Dsl

module Value = struct
  type t = T: 'a Type.t * 'a -> t

  let rec sexp_of_struct : type a. a Type.List.t -> a -> Sexp.t list =
   fun spec s ->
    match (spec, s) with
    | (Type.List.[], ()) -> []
    | (Type.List.(t :: spec), (x, s)) ->
        sexp_of_t (T (t, x)) :: sexp_of_struct spec s

  and sexp_of_t (T (typ, x)) =
    let open Type in
    match typ with
    | Pointer _ -> Pointer.sexp_of_t x
    | Uint32 -> Sexp.of_string (Unsigned.UInt32.to_string x)
    | Bool -> Bool.sexp_of_t x
    | Array Uint32 ->
        [%sexp_of : string array] (Array.map x ~f:Unsigned.UInt32.to_string)
    | Array Bool -> [%sexp_of : bool array] x
    | Array _ -> [%sexp_of : unit sexp_opaque] ()
    | Struct spec -> Sexp.List (sexp_of_struct spec x)
    | Function _ -> [%sexp_of : unit sexp_opaque] ()
    | Type -> Sexp.of_string "Type"
    | Label -> Sexp.of_string "Label"
    | Void -> Sexp.of_string "Void"

  let conv : type a. t -> a Type.t -> a option =
   fun (T (typ0, x)) typ1 ->
    match Type.equality typ0 typ1 with
    | Some Type_equal.T -> Some x
    | None -> None
end

let get_id =
  let r = ref 0 in
  fun () ->
    let x = !r in
    incr r ; x

let name_of_constant : ?label:string -> Value.t -> string =
 fun ?label v ->
  match label with
  | Some l -> l
  | None ->
    match v with
    | Value.T (Type.Bool, x) ->
        sprintf "c_bool_%s" (Bool.to_string x)
    | Value.T (Type.Uint32, x) ->
        sprintf "c_uint32_%s" (Unsigned.UInt32.to_string x)
    | _ -> sprintf "c_%d" (get_id ())

module State = struct
  (* TODO: Use or get rid of used_names *)
  type t =
    { bindings: Value.t String.Map.t
    ; pointer_values: Value.t Location.Map.t
    ; prefix: string }
  [@@deriving sexp_of]

  let empty =
    {bindings= String.Map.empty; pointer_values= Location.Map.empty; prefix= ""}

  let name_in_scope s name = s.prefix ^ "_" ^ name

  let create_id s typ name = Id.Id (typ, name_in_scope s name, 0)

  let get_lab_exn {bindings; _} lab typ =
    match String.Map.find bindings lab with
    | None -> failwithf "get_lab_exn: %s" lab ()
    | Some v ->
      match Value.conv v typ with
      | None -> failwithf "Conversion failure for %s" lab ()
      | Some x -> x

  let get_exn (type a) s (v: a Id.t) : a =
    match v with Id.Id (typ, lab, _value) -> get_lab_exn s lab typ

  let deref_exn (type a) s (loc: Location.t) (typ: a Type.t) : a =
    Option.value_exn (Value.conv (Map.find_exn s.pointer_values loc) typ)

  let set_pointer_value (type a) s (loc: Location.t) (x: a Id.t) =
    let value = String.Map.find_exn s.bindings (Id.name x) in
    let pointer_values = Location.Map.set s.pointer_values loc value in
    {s with pointer_values}

  let clear s label = {s with bindings= Map.remove s.bindings label}

  let set_exn (type a) s (v: a Id.t) (x: a) =
    match v with Id.Id (typ, lab, _value) ->
      if Map.mem s.bindings lab then failwithf "Duplicate binding: %s" lab () ;
      let key = lab in
      {s with bindings= Map.set ~key ~data:(Value.T (typ, x)) s.bindings}

  let set_ignore_duplicate_exn (type a) s (v: a Id.t) (x: a) =
    match v with Id.Id (typ, lab, _value) ->
      let key = lab in
      {s with bindings= Map.set ~key ~data:(Value.T (typ, x)) s.bindings}
end

let rec struct_get : type a b c. b Type.List.t -> b -> (a, b) Elem.t -> a = fun witness str elem ->
    match (witness, str, elem) with
    | (Type.List.(_ :: _), (x, _), Elem.Here) -> x
    | (Type.List.(_ :: t), (_, x), Elem.There e) -> struct_get t x e
    | _ -> .

let eval_op (type a) (s: State.t) ({op; result_name}: a Op.Value.t) :
    State.t * a Id.t =
  let open Op.Value in
  match op with
  | Bitwise_or (x, y) ->
      let x = State.get_exn s x in
      let y = State.get_exn s y in
      let id = Id.Id (Type.Uint32, result_name, 0) in
      (State.set_exn s id (UInt32.logor x y), id)
  | Mul_ignore_overflow (x, y) ->
      let x = State.get_exn s x in
      let y = State.get_exn s y in
      let id = Id.Id (Type.Uint32, result_name, 0) in
      (State.set_exn s id (UInt32.mul x y), id)
  | Div_ignore_remainder (x, y) ->
      let x = State.get_exn s x in
      let y = State.get_exn s y in
      let id = Id.Id (Type.Uint32, result_name, 0) in
      (State.set_exn s id (UInt32.div x y), id)
  | Mul (x, y) ->
      let x = State.get_exn s x in
      let y = State.get_exn s y in
      let low_bits = UInt32.mul x y in
      let high_bits =
        let c = Fn.compose Bigint.of_int UInt32.to_int in
        let unc = Fn.compose UInt32.of_int Bigint.to_int_exn in
        unc Bigint.(shift_right (c x * c y) 32)
      in
      let r = (low_bits, (high_bits, ())) in
      let id = Id.Id (Type.arithmetic_result, result_name, 0) in
      (State.set_exn s id r, id)
  | Add_ignore_overflow (x, y) ->
      let x = State.get_exn s x in
      let y = State.get_exn s y in
      let id = Id.Id (Type.Uint32, result_name, 0) in
      (State.set_exn s id (UInt32.add x y), id)
  | Add (x, y) ->
      let x = State.get_exn s x in
      let y = State.get_exn s y in
      let low_bits = UInt32.add x y in
      let high_bits =
        if UInt32.compare low_bits x < 0 then UInt32.one else UInt32.zero
      in
      let r = (low_bits, (high_bits, ())) in
      let id = Id.Id (Type.arithmetic_result, result_name, 0) in
      (State.set_exn s id r, id)
  | Sub_ignore_overflow (x, y) ->
      let x = State.get_exn s x in
      let y = State.get_exn s y in
      let id = Id.Id (Type.Uint32, result_name, 0) in
      (State.set_exn s id (UInt32.sub x y), id)
  | Sub (x, y) ->
      let x = State.get_exn s x in
      let y = State.get_exn s y in
      let low_bits = UInt32.sub x y in
      let high_bits =
        if UInt32.compare low_bits x > 0 then UInt32.one else UInt32.zero
      in
      let r = (low_bits, (high_bits, ())) in
      let id = Id.Id (Type.arithmetic_result, result_name, 0) in
      (State.set_exn s id r, id)
  | Or (x, y) ->
      let x = State.get_exn s x in
      let y = State.get_exn s y in
      let id = Id.Id (Type.Bool, result_name, 0) in
      (State.set_exn s id (x || y), id)
  | Equal (x, y) ->
      let x = State.get_exn s x in
      let y = State.get_exn s y in
      let id = Id.Id (Type.Bool, result_name, 0) in
      (State.set_exn s id (Int.( = ) (Unsigned.UInt32.compare x y) 0), id)
  | Less_than (x, y) ->
      let x = State.get_exn s x in
      let y = State.get_exn s y in
      let id = Id.Id (Type.Bool, result_name, 0) in
      (State.set_exn s id (Unsigned.UInt32.compare x y < 0), id)
  | Struct_get (str_id, str_elem) ->
      let str = State.get_exn s str_id in
      let str_type = Id.typ str_id in
      let types = Type.struct_types str_type in
      let elt = struct_get types str str_elem in
      let id = State.create_id s (Type.struct_elt str_type str_elem) result_name in
      (State.set_exn s id elt, id)
  | Array_access (arr_ptr_id, idx_id) ->
      let loc = match State.get_exn s arr_ptr_id with
        | Pointer.Pointer loc -> loc
        | Pointer.Array_pointer _ -> failwith "interpreter does not support nested array pointers"
      in
      let idx = State.get_exn s idx_id in
      let typ = Type.Pointer (Type.array_elt @@ Type.pointer_elt @@ Id.typ arr_ptr_id) in
      let ptr = Pointer.Array_pointer (loc, UInt32.to_int idx) in
      let id = State.create_id s typ result_name in
      (State.set_exn s id ptr, id)
  | Load ptr ->
      let typ = Type.pointer_elt (Id.typ ptr) in
      let value = match State.get_exn s ptr with
          | Pointer.Pointer loc -> State.deref_exn s loc typ
          | Pointer.Array_pointer (loc, index) ->
            let arr = State.deref_exn s loc (Type.Array typ) in
            arr.(index)
      in
      let id = State.create_id s typ result_name in
      (State.set_exn s id value, id)

let ptr_value_id ptr = Id.Id (Type.pointer_elt (Id.typ ptr), Id.name ptr, 0)

let eval_action_op s (op: Op.Action.t) =
  let open Op.Action in
  match op with
  | Store (ptr, value) ->
    let typ = Type.pointer_elt (Id.typ ptr) in
    (match State.get_exn s ptr with
      | Pointer.Pointer loc -> State.set_pointer_value s loc value
      | Pointer.Array_pointer (loc, index) ->
        let arr = State.deref_exn s loc (Type.Array typ) in
        arr.(index) <- State.get_exn s value;
        s)

let rec eval : type a. State.t -> a T.t -> State.t * a =
 fun s t ->
  let open T in
  match t with
  | Pure x -> (s, x)
  (* TODO: Prefixes interact incorrectly with constants *)
  | Set_prefix (prefix, k) ->
      eval {s with prefix} k
  | Declare_function _ ->
      failwith "Declare_function not implemented in interpreter"
  | Call_function _ ->
      failwith "Call_function not implemented in interpreter"
  | Declare_constant (typ, x, k) ->
      let id = Id.Id (typ, name_of_constant (Value.T (typ, x)), 0) in
      let s = State.set_ignore_duplicate_exn s id x in
      eval s (k id)
  | For {range= a, b; body; after} ->
      let a = Unsigned.UInt32.to_int (State.get_exn s a) in
      let b = Unsigned.UInt32.to_int (State.get_exn s b) in
      let label = sprintf "loop_%d" (get_id ()) in
      let id = State.create_id s Type.Uint32 label in
      let rec go s0 i =
        if i > b then eval s0 (after ())
        else
          let s_in_body = State.set_exn s0 id (Unsigned.UInt32.of_int i) in
          let s, _ = eval s_in_body (body id) in
          go {s with bindings= s0.bindings} (i + 1)
      in
      go s a
  | Action_op (op, k) ->
      let s = eval_action_op s op in
      eval s (k ())
  | Value_op (op, k) ->
      let s, id = eval_op s op in
      eval s (k id)
  | If {cond; then_; else_; after} ->
      let cond = State.get_exn s cond in
      let s, value = if cond then eval s (then_ ()) else eval s (else_ ()) in
      eval s (after value)
  | Do_if {cond; then_; after} ->
      let cond = State.get_exn s cond in
      if cond then
        let s, _ = eval s (then_ ()) in
        eval s (after ())
      else eval s (after ())
