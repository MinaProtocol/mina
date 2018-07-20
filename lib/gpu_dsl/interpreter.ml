open Core
open Unsigned
open Dsl

module Value = struct
  type t =
    | T : 'a Type.t * 'a -> t

  let rec sexp_of_struct : type a. a Type.list -> a PolyTuple.t -> Sexp.t list =
    fun spec s ->
      match spec, s with
      | Type.[], PolyTuple.[] -> []
      | Type.(::) (t, spec), PolyTuple.(::) (x, s) ->
        sexp_of_t (T (t, x)) :: sexp_of_struct spec s
  and sexp_of_t (T (typ, x)) =
    let open Type in
    let open Scalar in
    match typ with
    | Arith_result -> Sexp.of_string "Arith_result"
    | Pointer _ -> Pointer.sexp_of_t x
    | Tuple2 (ta, tb) ->
      let (a, b) = x in
      [%sexp_of: Sexp.t * Sexp.t]
        (sexp_of_t (T (Scalar ta, a)), sexp_of_t (T (Scalar tb, b)))
    | Scalar Uint32 -> Sexp.of_string (Unsigned.UInt32.to_string x)
    | Scalar Bool -> Bool.sexp_of_t x
    | Array Uint32 ->
      [%sexp_of: string array]
      (Array.map x ~f:Unsigned.UInt32.to_string)
    | Array Bool -> [%sexp_of: bool array] x
    | Struct spec -> [%sexp_of: unit sexp_opaque] () (* TODO: Sexp.List (sexp_of_struct spec x) *)
    | Function _ -> [%sexp_of: unit sexp_opaque] ()
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
    incr r;
    x

let name_of_constant : ?label:string -> Value.t -> string =
  fun ?label v ->
    match label with
    | Some l -> l
    | None -> 
      match v with
      | Value.T (Type.Scalar Type.Scalar.Bool, x) ->
        sprintf "c_bool_%s" (Bool.to_string x)
      | Value.T (Type.Scalar Type.Scalar.Uint32, x) ->
        sprintf "c_uint32_%s" (Unsigned.UInt32.to_string x)
      | _ ->
        sprintf "c_%d" (get_id ())


module State = struct
  (* TODO: Use or get rid of used_names *)
  type t =
    { bindings : Value.t String.Map.t
    ; pointer_values : Value.t Location.Map.t
    ; prefix : string
    }
  [@@deriving sexp_of]

  let empty =
    { bindings = String.Map.empty
    ; pointer_values = Location.Map.empty
    ; prefix = ""
    }

  let name_in_scope s lab = s.prefix ^ "_" ^ lab

  let create_id s typ lab =
    Id.Id (typ, name_in_scope s lab, 0)

  let get_lab_exn { bindings; _ } lab typ =
    match String.Map.find bindings lab with
    | None -> failwithf "get_lab_exn: %s" lab ()
    | Some v ->
      match Value.conv v typ with
      | None -> failwithf "Conversion failure for %s" lab ()
      | Some x -> x

  let get_exn (type a) s (v : a Id.t) : a =
    match v with
    | Id.Id (typ, lab, _value) ->
      get_lab_exn s lab typ

  let deref_exn (type a) s (loc : Location.t) (typ : a Type.t) : a =
    Option.value_exn
      (Value.conv
         (Map.find_exn s.pointer_values loc) typ)

  let set_pointer_value (type a) s (loc : Location.t) (x : a Id.t) =
    let value = String.Map.find_exn s.bindings (Id.name x) in
    let pointer_values = Location.Map.set s.pointer_values loc value in
    { s with pointer_values }

  let clear s label =
    { s with bindings = Map.remove s.bindings label }

  let set_exn (type a) s (v : a Id.t) (x : a) =
    match v with
    | Id.Id (typ, lab, _value) ->
      (if Map.mem s.bindings lab
       then failwithf "Duplicate binding: %s" lab ());
      let key = lab in
      { s with
        bindings = Map.set ~key ~data:(Value.T (typ, x)) s.bindings }

  let set_ignore_duplicate_exn (type a) s (v : a Id.t) (x : a) =
    match v with
    | Id.Id (typ, lab, _value) ->
      let key = lab in
      { s with
        bindings = Map.set ~key ~data:(Value.T (typ, x)) s.bindings }
end

let eval_op (type a) (s : State.t) ({op; result_name} : a Op.Value.t) : State.t * a Id.t =
  let open Op.Value in
  match op with
  | Fst t ->
    let (x, _) = State.get_exn s t in
    let id = Id.Id (Type.fst (Id.typ t), result_name, 0) in
    (State.set_exn s id x, id)
  | Snd t ->
    let (_, y) = State.get_exn s t in
    let id = Id.Id (Type.snd (Id.typ t), result_name, 0) in
    (State.set_exn s id y, id)
  | Bitwise_or (x, y) ->
    let x = State.get_exn s x in
    let y = State.get_exn s y in
    let id = Id.Id (Type.uint32, result_name, 0) in
    (State.set_exn s id (UInt32.logor x y), id)
  | Mul_ignore_overflow (x, y) ->
    let x = State.get_exn s x in
    let y = State.get_exn s y in
    let id = Id.Id (Type.uint32, result_name, 0) in
    (State.set_exn s id (UInt32.mul x y), id)
  | Div_ignore_remainder (x, y) ->
    let x = State.get_exn s x in
    let y = State.get_exn s y in
    let id = Id.Id (Type.uint32, result_name, 0) in
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
    let r = {Arith_result.low_bits; high_bits} in
    let id = Id.Id (Type.Arith_result, result_name, 0) in
    (State.set_exn s id r, id)
  | Add_ignore_overflow (x, y) ->
    let x = State.get_exn s x in
    let y = State.get_exn s y in
    let id = Id.Id (Type.uint32, result_name, 0) in
    (State.set_exn s id (UInt32.add x y), id)
  | Add (x, y) ->
    let x = State.get_exn s x in
    let y = State.get_exn s y in
    let low_bits = UInt32.add x y in
    let high_bits = if (UInt32.compare low_bits x < 0) then UInt32.one else UInt32.zero in
    let r = {Arith_result.low_bits; high_bits} in
    let id = Id.Id (Type.Arith_result, result_name, 0) in
    (State.set_exn s id r, id)
  | Sub_ignore_overflow (x, y) ->
    let x = State.get_exn s x in
    let y = State.get_exn s y in
    let id = Id.Id (Type.uint32, result_name, 0) in
    (State.set_exn s id (UInt32.sub x y), id)
  | Sub (x, y) ->
    let x = State.get_exn s x in
    let y = State.get_exn s y in
    let low_bits = UInt32.sub x y in
    let high_bits = if (UInt32.compare low_bits x > 0) then UInt32.one else UInt32.zero in
    let r = {Arith_result.low_bits; high_bits} in
    let id = Id.Id (Type.Arith_result, result_name, 0) in
    (State.set_exn s id r, id)
  | High_bits t ->
    let t = State.get_exn s t in
    let id = Id.Id (Type.uint32, result_name, 0) in
    (State.set_exn s id t.high_bits, id)
  | Low_bits t ->
    let t = State.get_exn s t in
    let id = Id.Id (Type.uint32, result_name, 0) in
    (State.set_exn s id t.low_bits, id)
  | Or (x, y) ->
    let x = State.get_exn s x in
    let y = State.get_exn s y in
    let id = Id.Id (Type.bool, result_name, 0) in
    (State.set_exn s id (x || y), id)
  | Equal (x, y) ->
    let x = State.get_exn s x in
    let y = State.get_exn s y in
    let id = Id.Id (Type.bool, result_name, 0) in
    (State.set_exn s id (Int.(=) (Unsigned.UInt32.compare x y) 0), id)
  | Less_than (x, y) ->
    let x = State.get_exn s x in
    let y = State.get_exn s y in
    let id = Id.Id (Type.bool, result_name, 0) in
    (State.set_exn s id (Unsigned.UInt32.compare x y < 0), id)
  | Array_get (arr_id, idx_id) ->
    let arr = State.get_exn s arr_id in
    let i = State.get_exn s idx_id in
    let y = arr.(Unsigned.UInt32.to_int i) in
    let typ = Type.array_elt (Id.typ arr_id) in
    let id = Id.Id (typ, result_name, 0) in
    (State.set_exn s id y, id)

let ptr_value_id ptr =
  Id.Id (Type.pointer_elt (Id.typ ptr), Id.name ptr, 0)

let eval_action_op s (op : Op.Action.t) =
  let open Op.Action in
  match op with
  | Store (ptr, value) ->
    let Pointer.Pointer loc = State.get_exn s ptr in
    State.set_pointer_value s loc value

  | Array_set (arr_id, i, elt_id) ->
    let arr = State.get_exn s arr_id in
    let i = State.get_exn s i in
    let elt = State.get_exn s elt_id in
    arr.(Unsigned.UInt32.to_int i) <- elt;
    s

let rec eval : type a. State.t -> a T.t -> State.t * a =
  fun s t ->
    let open T in
    match t with
    | Pure x -> (s, x)
    (* TODO: Prefixes interact incorrectly with constants *)
    | Set_prefix (prefix, k) -> eval { s with prefix } k
    | Load (ptr, lab, k) ->
      let Pointer.Pointer loc = State.get_exn s ptr in
      let typ =
        match Id.typ ptr with
        | Type.Pointer t -> t
        | _ -> assert false
      in
      let value = State.deref_exn s loc typ in
      let id = State.create_id s typ lab in
      let s = State.set_exn s id value in
      eval s (k id)
    | Declare_constant (typ, x, k) ->
      let id = Id.Id (typ, name_of_constant (Value.T (typ, x)), 0) in
      let s = State.set_ignore_duplicate_exn s id x in
      eval s (k id)
    | Create_pointer (typ, lab, k) ->
      let id = State.create_id s (Type.Pointer typ) lab in
      let loc = Location.create () in
      let s = State.set_exn s id (Pointer loc) in
      eval s (k id)
    | For { range=(a, b); body; after } ->
      let a = Unsigned.UInt32.to_int (State.get_exn s a) in
      let b = Unsigned.UInt32.to_int (State.get_exn s b) in
      let label = sprintf "loop_%d" (get_id ()) in
      let id = State.create_id s Type.uint32 label in
      let rec go s0 i =
        if i > b
        then eval s0 (after ())
        else
          let s_in_body = State.set_exn s0 id (Unsigned.UInt32.of_int i) in
          let (s, _) = eval s_in_body (body id) in
          go { s with bindings = s0.bindings } (i + 1)
      in
      go s a
    | Action_op (op, k) ->
      let s = eval_action_op s op in
      eval s (k ())
    | Value_op (op, k) ->
      let (s, id) = eval_op s op in
      eval s (k id)
    | If { cond; then_; else_; after } ->
      let cond = State.get_exn s cond in
      let (s, value) = (if cond then eval s (then_ ()) else eval s (else_ ())) in
      eval s (after value)
    | Do_if { cond; then_; after } ->
      let cond = State.get_exn s cond in
      if cond
      then
        let (s, _) = eval s (then_ ()) in
        eval s (after ())
      else eval s (after ())
