open Core
open Unsigned

(* kernel inputs:

   - specialization constants (compile time constants)
   - push constants (can be changed for each batch of invocations) (e.g., how many times should a loop be performed)
   - "input"/"output" buffers: (have a list of them)
      - Each gets a descriptor set
   (input and output locations)
*)

module Procedure = struct
  type 'a t = 'a -> unit
end

module Location : sig
  type t

  include Comparable.S with type t := t
  include Sexpable.S with type t := t

  val create : unit -> t
end = struct
  include Int

  let create =
    let r = ref 0 in
    fun () ->
      let x = !r in
      incr r;
      x
end

module Pointer = struct
  type 'a t = Pointer of Location.t

  let sexp_of_t (Pointer loc) =
    Sexp.List [ Atom "pointer"; Location.sexp_of_t loc ]
end

module Arith_result = struct
  type 'a t =
    { low_bits : 'a
    ; high_bits : 'a
    }
end

module Struct = struct
  type 'a t =
    | [] : unit t
    | (::) : 'a * 'b t -> ('a * 'b) t
end


module Typ = struct
  module Scalar = struct
    type 'a t =
      | Uint32 : uint32 t
      | Bool : bool t
    [@@deriving hash]

    let equality : type a b. a t -> b t -> (a, b) Type_equal.t option =
      fun x y ->
        match x, y with
        | Uint32, Uint32 -> Some Type_equal.T
        | Bool, Bool -> Some Type_equal.T
        | _, _ -> None

    let equal : type a b. a t -> b t -> bool =
      fun x y -> Option.is_some (equality x y)
  end

  type _ t =
    | Scalar  : 'a Scalar.t -> 'a t
    | Pointer : 'a Scalar.t -> 'a Pointer.t t
    | Array   : 'a Scalar.t -> 'a array t
    | Tuple2  : 'a Scalar.t * 'b Scalar.t -> ('a * 'b) t
    | Arith_result  : uint32 Arith_result.t t
    | Struct : 'a struct_spec -> 'a Struct.t t
    | Procedure : 'a t -> 'a Procedure.t t
  and _ struct_spec =
    | [] : unit struct_spec
    | (::) : 'a t * 'b struct_spec -> ('a * 'b) struct_spec

  let fst : type a b. (a * b) t -> a t = function
    | Tuple2 (x,_) -> Scalar x
    | _ -> assert false

  let snd : type a b. (a * b) t -> b t = function
    | Tuple2 (x, y) -> Scalar y
    | _ -> assert false

  let pointer_elt : type a. a Pointer.t t -> a t = function
    | Pointer scalar -> Scalar scalar
    | _ -> assert false

  let array_elt : type a. a array t -> a t = function
    | Array scalar -> Scalar scalar
    | _ -> assert false

  let equality : type a b. a t -> b t -> (a, b) Type_equal.t option =
    fun x y ->
      match x, y with
      | Pointer a1, Pointer a2 ->
        begin match Scalar.equality a1 a2 with
        | Some Type_equal.T -> Some Type_equal.T
        | None -> None
        end
      | Arith_result, Arith_result -> Some Type_equal.T
      | Tuple2 (a1, b1), Tuple2 (a2, b2) ->
        begin match Scalar.equality a1 a2, Scalar.equality b1 b2 with
        | Some Type_equal.T, Some Type_equal.T -> Some Type_equal.T
        | _ -> None
        end
      | Scalar a, Scalar b -> Scalar.equality a b
      | Array a, Array b ->
        begin match Scalar.equality a b with
        | Some Type_equal.T -> Some Type_equal.T
        | None -> None
        end
      | _, _ -> None

  let uint32 = Scalar Uint32
  let bool = Scalar Bool
end

module Struct_location = struct
  type ('a, 's) t =
    | Here : ('a, 'a * 'b) t
    | There : ('a, 's) t -> ('a, 'b * 's) t
end

module Value = struct
  type t =
    | T : 'a Typ.t * 'a -> t

  let rec sexp_of_t (T (typ, x)) =
    let open Typ in
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

  let conv : type a. t -> a Typ.t -> a option =
    fun (T (typ0, x)) typ1 ->
      match Typ.equality typ0 typ1 with
      | Some Type_equal.T -> Some x
      | None -> None
end

(*
module Kernel_input = struct
  type t =
    { specialization_constants
      : Specialization_constant.t list
    ; push_constants
      : Push_constant.t list
    ; arguments
      : Argument.t list
    }
   end *)

(* SSA Id *)
module Id = struct
  type 'a t =
    | Id : 'a Typ.t * string -> 'a t

  let sexp_of_t = function
    | Id (_, lab) -> 
      Sexp.List [ Atom "Id"; List [Atom "<opaque>"; Atom lab]]

  let typ = function
    | Id (typ, _) -> typ

  let label = function
    | Id (_, s) -> s

  let pointer typ lab = Id (Typ.Pointer typ, lab)

  let dummy typ = Id (typ, "dummy")
end

module Ctx : sig
  type t
end = struct
  type t = Todo
end

module UInt32 = Unsigned.UInt32

module Op = struct
  (* First arg is the result *)
  module Value = struct
    type 'a op =
      | Or : bool Id.t * bool Id.t -> bool op
      | Add : uint32 Id.t * uint32 Id.t -> uint32 Arith_result.t op
      | Add_ignore_overflow : uint32 Id.t * uint32 Id.t -> uint32 op
      | Sub : uint32 Id.t * uint32 Id.t -> uint32 Arith_result.t op
      | Sub_ignore_overflow : uint32 Id.t * uint32 Id.t -> uint32 op
      | Mul : uint32 Id.t * uint32 Id.t -> uint32 Arith_result.t op
      | Mul_ignore_overflow : uint32 Id.t * uint32 Id.t -> uint32 op
      | Div_ignore_remainder : uint32 Id.t * uint32 Id.t -> uint32 op
      | Bitwise_or : uint32 Id.t * uint32 Id.t -> uint32 op
      | Less_than : uint32 Id.t * uint32 Id.t -> bool op
      | Equal : uint32 Id.t * uint32 Id.t -> bool op
      | Array_get : 'b array Id.t * uint32 Id.t -> 'b op
      | Struct_access : 's Struct.t Id.t * ('a, 's) Struct_location.t -> 'a op
      | Fst : ('a * 'b) Id.t -> 'a op
      | Snd : ('a * 'b) Id.t -> 'b op
      | High_bits : uint32 Arith_result.t Id.t -> uint32 op
      | Low_bits : uint32 Arith_result.t Id.t -> uint32 op

    type 'a t = { op : 'a op; label : string }

    let rec struct_access
      : type a s. s Typ.struct_spec -> (a, s) Struct_location.t -> a Typ.t
      =
      let open Typ in
      let open Struct_location in
      fun spec loc ->
        match spec, loc with
        | typ :: _ , Here -> typ
        | _ :: spec, There loc -> struct_access spec loc
        | [], _ -> .

    let typ : type a. a op -> a Typ.t = function
      | Or _ -> Typ.bool
      | Add _ -> Typ.Arith_result
      | Add_ignore_overflow _ -> Typ.uint32
      | Sub _ -> Typ.Arith_result
      | Sub_ignore_overflow _ -> Typ.uint32
      | Mul _ -> Typ.Arith_result
      | Mul_ignore_overflow _ -> Typ.uint32
      | Div_ignore_remainder _ -> Typ.uint32
      | Bitwise_or _ -> Typ.uint32
      | Less_than _ -> Typ.bool
      | Equal _ -> Typ.bool
      | High_bits _ -> Typ.uint32
      | Low_bits _ -> Typ.uint32
      | Array_get (arr, _) -> Typ.array_elt (Id.typ arr)
      | Fst t -> Typ.fst (Id.typ t)
      | Snd t -> Typ.snd (Id.typ t)
      | Struct_access (id, loc) ->
        begin match Id.typ id with
        | Typ.Struct spec -> struct_access spec loc
        | _ -> assert false
        end
  end

  module Action = struct
    type t =
      | Array_set : 'b array Id.t * uint32 Id.t * 'b Id.t -> t
      | Store : 'a Pointer.t Id.t * 'a Id.t -> t
  end
end

module Arguments_spec = struct
  type ('acc, 'arg_type, 'k) t =
    | [] : ('k, unit, 'k) t
    | (::) : 'a Typ.t * ('b, 'at, 'k) t -> ('a Id.t -> 'b, 'a Id.t * 'at, 'k) t
end

module Local_variables_spec = struct
  type ('acc, 'k) t =
    | [] : ('k, 'k) t
    | (::) : 'a Typ.t * ('b, 'k) t -> ('a Pointer.t Id.t -> 'b, 'k) t
end

module T = struct
  type 'a t =
    | Set_prefix of string * 'a t
    | Declare_procedure
      : string
        * ('f, 'for_id, 'g) Arguments_spec.t
        * ('g, unit t) Local_variables_spec.t
        * 'f
        * ('for_id Procedure.t Id.t -> 'a t)
        -> 'a t
    | Call_procedure
      : 's Procedure.t Id.t
        * 's Struct.t
        * (unit -> 'a t)
      -> 'a t
    | Create_pointer
      : 'c Typ.Scalar.t * string
        * ('c Pointer.t Id.t -> 'b t) ->  'b t
    | Load : 'c Pointer.t Id.t * string * ('c Id.t -> 'a t) -> 'a t
    | Value_op : 'a Op.Value.t * ('a Id.t -> 'b t) -> 'b t
    | Action_op of Op.Action.t * (unit -> 'a t)
    | Declare_constant : 'a Typ.t * 'a * string option * ('a Id.t -> 'b t) -> 'b t
    | For of
        { range: (uint32 Id.t * uint32 Id.t)
        ; closure : string list
        ; body : (uint32 Id.t -> unit t)
        ; after : ( unit -> 'a t)
        }
    | Phi of string list * (unit -> 'a t)
    | Do_if :
        { cond : bool Id.t
        ; then_ : unit t
        ; after : (unit -> 'a t) 
        }
        -> 'a t
    | If :
        { cond : bool Id.t
        ; then_ : 'b Id.t
        ; else_ : 'b Id.t
        ; after : ('b Id.t -> 'a t) 
        }
        -> 'a t
    | Pure of 'a

  let rec map t ~f =
    match t with
    | Call_procedure (id, arg, k) ->
      Call_procedure (id, arg, fun () -> map (k ()) ~f)
    | Declare_procedure (name, args, vars, body, k) ->
      Declare_procedure (name, args, vars, body, fun x -> map (k x) ~f)
    | Pure x -> Pure (f x)
    | Set_prefix (s, k) -> Set_prefix (s, map k ~f)
    | Declare_constant (typ, x, lab, k) ->
      Declare_constant (typ, x, lab, fun v -> map (k v) ~f)
    | Create_pointer (typ, s, k) ->
      Create_pointer (typ, s, fun v -> map (k v) ~f)
    | Load (ptr, lab, k) ->
      Load (ptr, lab, fun v -> map (k v) ~f)
    | Action_op (op, k) -> Action_op (op, fun () -> map (k ()) ~f)
    | Value_op (op, k) -> Value_op (op, fun v -> map (k v) ~f)
    | For { range; closure; body; after } ->
      For { range; closure; body; after = fun ctx -> map (after ctx) ~f }
    | Phi (vs, k) -> Phi (vs, fun () -> map (k ()) ~f)
    | If { cond; then_; else_; after } ->
      If { cond; then_; else_; after = fun v -> map (after v) ~f }
    | Do_if { cond; then_; after } ->
      Do_if { cond; then_; after = fun x -> map (after x) ~f }

  let rec bind : type a b. a t -> f:(a -> b t) -> b t =
    fun t ~f ->
      match t with
      | Declare_procedure (name, args, vars, body, k) ->
        Declare_procedure (name, args, vars, body, fun x -> bind (k x) ~f)
      | Call_procedure (id, arg, k) ->
        Call_procedure (id, arg, fun () -> bind (k ()) ~f)
      | Pure x -> f x
      | Set_prefix (s, k) -> Set_prefix (s, bind k ~f)
      | Create_pointer (typ, s, k) ->
        Create_pointer (typ, s, fun v -> bind (k v) ~f)
      | Declare_constant (typ, x, lab, k) ->
        Declare_constant (typ, x, lab, fun v -> bind (k v) ~f)
      | Load (ptr, lab, k) ->
        Load (ptr, lab, fun v -> bind (k v) ~f)
      | Action_op (op, k) -> Action_op (op, fun () -> bind (k ()) ~f)
      | Value_op (op, k) -> Value_op (op, fun v -> bind (k v) ~f)
      | For { range; closure; body; after } ->
        For { range; closure; body; after = fun ctx -> bind (after ctx) ~f }
      | Phi (vs, k) -> Phi (vs, fun () -> bind (k ()) ~f)
      | If { cond; then_; else_; after } ->
        If { cond; then_; else_; after = fun v -> bind (after v) ~f }
      | Do_if { cond; then_; after } ->
        Do_if { cond; then_; after = fun x -> bind (after x) ~f }

  let return x = Pure x

  (* TODO: Compute closure from the body *)
  let for_ range body = For { range; closure = []; body; after = fun _ -> return () }
  let if_ cond ~then_ ~else_ = If { cond; then_; else_; after = fun v -> return v }
  let do_if cond then_ = Do_if { cond; then_; after = fun v -> return v }

  let set_prefix prefix = Set_prefix (prefix, return ())

  let array_get label arr i =
    Value_op ({ op = Array_get (arr, i); label }, return)

  let do_value op label = Value_op ({ op; label }, return)
  let do_ op = Action_op (op, fun () -> return ())

  let constant ?label typ x =
    Declare_constant (typ, x, label, return)

  let declare_procedure name ~args ~vars body =
    Declare_procedure (name, args, vars, body, return)
end

include Monad.Make(struct
    include T
    let map = `Custom map
  end)

include T
open Let_syntax

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
      | Value.T (Typ.Scalar Typ.Scalar.Bool, x) ->
        sprintf "c_bool_%s" (Bool.to_string x)
      | Value.T (Typ.Scalar Typ.Scalar.Uint32, x) ->
        sprintf "c_uint32_%s" (Unsigned.UInt32.to_string x)
      | _ ->
        sprintf "c_%d" (get_id ())

module Compiler = struct
  let step : type a. a t -> [ `Done of a | `Continue of a t] =
    fun t ->
      match t with
      | Pure x -> `Done x
      | Set_prefix (_s, k) -> `Continue k
      | Declare_constant (typ, x, lab, k) -> `Continue (k (Id.dummy typ))
      | Create_pointer (typ, s, k) -> `Continue (k (Id.pointer typ s))
      | Load (ptr, lab, k) -> `Continue (k (Id.dummy (Typ.pointer_elt (Id.typ ptr))))
      | Action_op (op, k) -> `Continue (k ())
      | Phi (_, k) -> `Continue (k ())
      | Value_op (op, k) ->
        `Continue (k (Id.dummy (Op.Value.typ op.op)))
      | For { after; _ } -> `Continue (after ())
      | Do_if { after; _} -> `Continue (after ())
      | If { after; then_; _} -> `Continue (after (Id.dummy (Id.typ then_)))
  ;;

  let constants =
    let rec go : type a. a t -> Value.t list -> Value.t list =
      fun t acc ->
        let acc =
          match t with
          | Declare_constant (typ, x, lab, k) ->
            Value.T (typ, x) :: acc
          | _ -> acc
        in
        match step t with
        | `Done _ -> acc
        | `Continue k -> go k acc
    in
    fun t -> go t []
end

module Interpreter = struct
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
      Id.Id (typ, name_in_scope s lab)

    let get_lab_exn { bindings; _ } lab typ =
      match String.Map.find bindings lab with
      | None -> failwithf "get_lab_exn: %s" lab ()
      | Some v ->
        match Value.conv v typ with
        | None -> failwithf "Conversion failure for %s" lab ()
        | Some x -> x

    let get_exn (type a) s (v : a Id.t) : a =
      match v with
      | Id.Id (typ, lab) ->
        get_lab_exn s lab typ

    let deref_exn (type a) s (loc : Location.t) (typ : a Typ.t) : a =
      Option.value_exn
        (Value.conv
           (Map.find_exn s.pointer_values loc) typ)

    let set_pointer_value (type a) s (loc : Location.t) (x : a Id.t) =
      let value = String.Map.find_exn s.bindings (Id.label x) in
      let pointer_values = Location.Map.set s.pointer_values loc value in
      { s with pointer_values }

    let clear s label =
      { s with bindings = Map.remove s.bindings label }

    let set_exn (type a) s (v : a Id.t) (x : a) =
      match v with
      | Id.Id (typ, lab) ->
        (if Map.mem s.bindings lab
         then failwithf "Duplicate binding: %s" lab ());
        let key = lab in
        { s with
          bindings = Map.set ~key ~data:(Value.T (typ, x)) s.bindings }

    let set_ignore_duplicate_exn (type a) s (v : a Id.t) (x : a) =
      match v with
      | Id.Id (typ, lab) ->
        let key = lab in
        { s with
          bindings = Map.set ~key ~data:(Value.T (typ, x)) s.bindings }
  end

  let eval_op (type a) (s : State.t) ({op; label} : a Op.Value.t) : State.t * a Id.t =
    let open Op.Value in
    match op with
    | Fst t ->
      let (x, _) = State.get_exn s t in
      let id = Id.Id (Typ.fst (Id.typ t), label) in
      (State.set_exn s id x, id)
    | Snd t ->
      let (_, y) = State.get_exn s t in
      let id = Id.Id (Typ.snd (Id.typ t), label) in
      (State.set_exn s id y, id)
    | Bitwise_or (x, y) ->
      let x = State.get_exn s x in
      let y = State.get_exn s y in
      let id = Id.Id (Typ.uint32, label) in
      (State.set_exn s id (UInt32.logor x y), id)
    | Mul_ignore_overflow (x, y) ->
      let x = State.get_exn s x in
      let y = State.get_exn s y in
      let id = Id.Id (Typ.uint32, label) in
      (State.set_exn s id (UInt32.mul x y), id)
    | Div_ignore_remainder (x, y) ->
      let x = State.get_exn s x in
      let y = State.get_exn s y in
      let id = Id.Id (Typ.uint32, label) in
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
      let id = Id.Id (Typ.Arith_result, label) in
      (State.set_exn s id r, id)
    | Add_ignore_overflow (x, y) ->
      let x = State.get_exn s x in
      let y = State.get_exn s y in
      let id = Id.Id (Typ.uint32, label) in
      (State.set_exn s id (UInt32.add x y), id)
    | Add (x, y) ->
      let x = State.get_exn s x in
      let y = State.get_exn s y in
      let low_bits = UInt32.add x y in
      let high_bits = if (UInt32.compare low_bits x < 0) then UInt32.one else UInt32.zero in
      let r = {Arith_result.low_bits; high_bits} in
      let id = Id.Id (Typ.Arith_result, label) in
      (State.set_exn s id r, id)
    | Sub_ignore_overflow (x, y) ->
      let x = State.get_exn s x in
      let y = State.get_exn s y in
      let id = Id.Id (Typ.uint32, label) in
      (State.set_exn s id (UInt32.sub x y), id)
    | Sub (x, y) ->
      let x = State.get_exn s x in
      let y = State.get_exn s y in
      let low_bits = UInt32.sub x y in
      let high_bits = if (UInt32.compare low_bits x > 0) then UInt32.one else UInt32.zero in
      let r = {Arith_result.low_bits; high_bits} in
      let id = Id.Id (Typ.Arith_result, label) in
      (State.set_exn s id r, id)
    | High_bits t ->
      let t = State.get_exn s t in
      let id = Id.Id (Typ.uint32, label) in
      (State.set_exn s id t.high_bits, id)
    | Low_bits t ->
      let t = State.get_exn s t in
      let id = Id.Id (Typ.uint32, label) in
      (State.set_exn s id t.low_bits, id)
    | Or (x, y) ->
      let x = State.get_exn s x in
      let y = State.get_exn s y in
      let id = Id.Id (Typ.bool, label) in
      (State.set_exn s id (x || y), id)
    | Equal (x, y) ->
      let x = State.get_exn s x in
      let y = State.get_exn s y in
      let id = Id.Id (Typ.bool, label) in
      (State.set_exn s id (Int.(=) (Unsigned.UInt32.compare x y) 0), id)
    | Less_than (x, y) ->
      let x = State.get_exn s x in
      let y = State.get_exn s y in
      let id = Id.Id (Typ.bool, label) in
      (State.set_exn s id (Unsigned.UInt32.compare x y < 0), id)
    | Array_get (arr_id, idx_id) ->
      let arr = State.get_exn s arr_id in
      let i = State.get_exn s idx_id in
      let y = arr.(Unsigned.UInt32.to_int i) in
      let typ = Typ.array_elt (Id.typ arr_id) in
      let id = Id.Id (typ, label) in
      (State.set_exn s id y, id)

  let ptr_value_id ptr =
    Id.Id (Typ.pointer_elt (Id.typ ptr), Id.label ptr)

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
          | Typ.Pointer t -> Typ.Scalar t
          | _ -> assert false
        in
        let value = State.deref_exn s loc typ in
        let id = State.create_id s typ lab in
        let s = State.set_exn s id value in
        eval s (k id)
      | Declare_constant (typ, x, label, k) ->
        let id = Id.Id (typ, name_of_constant ?label (Value.T (typ, x))) in
        let s = State.set_ignore_duplicate_exn s id x in
        eval s (k id)
      | Create_pointer (typ, lab, k) ->
        let id = State.create_id s (Typ.Pointer typ) lab in
        let loc = Location.create () in
        let s = State.set_exn s id (Pointer loc) in
        eval s (k id)
      | Phi (_, k) -> eval s (k ())
      | For { range=(a, b); closure=_; body; after } ->
        let a = Unsigned.UInt32.to_int (State.get_exn s a) in
        let b = Unsigned.UInt32.to_int (State.get_exn s b) in
        let label = sprintf "loop_%d" (get_id ()) in
        let id = State.create_id s Typ.uint32 label in
        let rec go s0 i =
          if i > b
          then eval s0 (after ())
          else
            let s_in_body = State.set_exn s0 id (Unsigned.UInt32.of_int i) in
            let (s, ()) = eval s_in_body (body id) in
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
        eval s (after (if cond then then_ else else_))
      | Do_if { cond; then_; after } ->
        let cond = State.get_exn s cond in
        if cond
        then
          let (s, ()) = eval s then_ in
          eval s (after ())
        else eval s (after ())
end

let array_get label xs i =
  let open Op.Value in
  do_value (Array_get (xs, i)) label

let array_set xs i x =
  do_ (Array_set (xs, i, x))

let less_than lab x y = do_value (Less_than (x, y)) lab

let create_pointer typ label =
  Create_pointer (typ, label, return)

let load ptr label =
  Load (ptr, label, return)

let store ptr value =
  Action_op (Op.Action.Store (ptr, value), return)

let high_bits x lab = do_value (High_bits x) lab
let low_bits x lab = do_value (Low_bits x) lab

let or_ x y lab = do_value (Or (x, y)) lab

let arith_op name k =
  stage
    (fun x y lab ->
      let%bind r = do_value (k x y) (sprintf "%s_%s_result" lab name) in
      let%map high_bits = high_bits r (lab ^ "_high_bits")
      and low_bits = low_bits r (lab ^ "_low_bits")
      in
      { Arith_result.high_bits; low_bits })

let add = unstage (arith_op "add" (fun x y -> Add (x, y)))
let sub = unstage (arith_op "sub" (fun x y -> Sub (x, y)))
let mul = unstage (arith_op "mul" (fun x y -> Mul (x, y)))

let add_ignore_overflow x y lab =
  do_value (Op.Value.Add_ignore_overflow (x, y)) lab

let bitwise_or x y lab =
  do_value (Op.Value.Bitwise_or (x, y)) lab

let equal_uint32 x y lab =
  do_value (Op.Value.Equal (x, y)) lab

let bigint_add n ~carry_pointer:carryp rs xs ys =
  let%bind () = set_prefix "bigint_add" in
(*   let%bind carryp = create_pointer Typ.Scalar.Uint32 "carryp" in *)
  let%bind () = constant Typ.uint32 UInt32.zero >>= store carryp in
  let%bind start = constant Typ.uint32 Unsigned.UInt32.zero in
  let%bind stop = constant Typ.uint32 Unsigned.UInt32.(sub n one) in
  for_ (start, stop) (fun i ->
    let%bind x = array_get "x" xs i
    and y = array_get "y" ys i
    in
    let%bind { high_bits=carry1; low_bits=x_plus_y } =
      add x y "x_plus_y"
    in
    let%bind carry = load carryp "carry" in
    let%bind {low_bits=x_plus_y_with_prev_carry; high_bits=carry2 } =
      add x_plus_y carry "x_plus_y_with_prev_carry"
    in
    let%bind () =
      let%bind new_carry = bitwise_or carry1 carry2 "new_carry" in
      store carryp new_carry
    in
    array_set rs i x_plus_y_with_prev_carry)

(* NB: This only works when ys <= xs *)
let bigint_sub n ~carry_pointer:carryp rs xs ys =
  let%bind () = set_prefix "bigint_sub" in
(*   let%bind carryp = create_pointer Typ.Scalar.Uint32 "carryp" in *)
  let%bind () = constant Typ.uint32 UInt32.zero >>= store carryp in
  let%bind start = constant Typ.uint32 Unsigned.UInt32.zero in
  let%bind stop = constant Typ.uint32 Unsigned.UInt32.(sub n one) in
  for_ (start, stop) (fun i ->
    let%bind x = array_get "x" xs i
    and y = array_get "y" ys i
    in
    let%bind { high_bits=carry1; low_bits=x_plus_y } =
      sub x y "x_plus_y"
    in
    let%bind carry = load carryp "carry" in
    let%bind {low_bits=x_plus_y_with_prev_carry; high_bits=carry2 } =
      sub x_plus_y carry "x_plus_y_with_prev_carry"
    in
    let%bind () =
      let%bind new_carry = bitwise_or carry1 carry2 "new_carry" in
      store carryp new_carry
    in
    array_set rs i x_plus_y_with_prev_carry)

(* Assumption: 2*p > 2^n *)
let bigint_add_mod ~p n rs xs ys =
  let%bind one = constant Typ.uint32 UInt32.one in
  let%bind zero = constant Typ.uint32 UInt32.zero in
  let%bind carry_pointer = create_pointer Typ.Scalar.Uint32 "carryp" in
  let%bind () = bigint_add ~carry_pointer n rs xs ys in
  let%bind carry_after_add = load carry_pointer "carry_after_add" in
  let%bind overflow = equal_uint32 carry_after_add one "overflow" in
  do_if overflow begin
    let%bind () = bigint_sub ~carry_pointer n rs rs p in
    let%bind last_carry = load carry_pointer "last_carry" in
    let%bind didn't_kill_top_bit = equal_uint32 last_carry zero "didnt_kill_top_bit" in
    do_if didn't_kill_top_bit
      (bigint_sub ~carry_pointer n rs rs p)
  end

let bigint_sub_mod ~p n rs xs ys =
  let%bind one = constant Typ.uint32 UInt32.one in
  let%bind zero = constant Typ.uint32 UInt32.zero in
  let%bind carry_pointer = create_pointer Typ.Scalar.Uint32 "carryp" in
  let%bind () = bigint_sub ~carry_pointer n rs xs ys in
  let%bind carry_after_sub = load carry_pointer "carry_after_sub" in
  let%bind underflow = equal_uint32 carry_after_sub one "underflow" in
  do_if underflow begin
    let%bind () = bigint_add ~carry_pointer n rs rs p in
    let%bind last_carry = load carry_pointer "last_carry" in
    let%bind didn't_kill_top_bit = equal_uint32 last_carry zero "didnt_kill_top_bit" in
    do_if didn't_kill_top_bit
      (bigint_add ~carry_pointer n rs rs p)
  end

let bigint_mul n ws xs ys =
  let%bind () = set_prefix "bigint_mul" in
  let%bind zero = constant Typ.uint32 UInt32.zero
  and num_limbs = constant Typ.uint32 n
  and stop = constant Typ.uint32 UInt32.(sub n one)
  in
  let start = zero in
  let%bind kp = create_pointer Typ.Scalar.Uint32 "kp" in
  for_ (start, stop) (fun j ->
    let%bind y = array_get "y" ys j in
    let%bind () = store kp zero in
    let%bind () =
      for_ (start, stop) (fun i ->
        let%bind i_plus_j = add_ignore_overflow i j "i_plus_j" in
        let%bind k = load kp "k_in_i_loop" in
        let%bind t =
          let%bind x = array_get "x" xs i in
          let%bind xy = mul x y "xy" in
          let%bind w = array_get "w" ws i_plus_j in
          (* Claim:
             x*y + w + k < 2^(2 * 32) (i.e., it will fit in 2 uint32s).

             We have
             x, y, w, k <= 2^32 - 1
             xy <= (2^32 - 1)(2^32 - 1) = 2^64 - 2 * 2^32 + 1

             so
             xy + w + k
             <= 2^64 - 2 * 2^32 + 1 + 2*(2^32 - 1)
             = 2^64 - 2 * 2^32 + 1 + 2 * 2^32 - 2
             = 2^64 - 2 * 2^32 + 2 * 2^32 + 1 - 2
             = 2^64 + 1 - 2
             = 2^64 - 1
          *)
          let%bind k_plus_w = add k w "k_plus_w" in
          let%bind xy_plus_k_plus_w_low_bits =
            add xy.low_bits k_plus_w.low_bits "xy_plus_k_plus_w_low_bits"
          in
          (* By the above there should be no overflow here *)
          let%map high_bits =
            let%bind intermediate =
              add_ignore_overflow
                xy.high_bits
                xy_plus_k_plus_w_low_bits.high_bits
                "intermediate"
            in
            add_ignore_overflow intermediate k_plus_w.high_bits
              "high_bits"
          in
          { Arith_result.high_bits
          ; low_bits = xy_plus_k_plus_w_low_bits.low_bits }
        in
        let%bind () = array_set ws i_plus_j t.low_bits in
        store kp t.high_bits
      )
    in
    let%bind k = load kp "k_in_j_loop" in
    let%bind j_plus_n = add_ignore_overflow j num_limbs "j_plus_n" in
    array_set ws j_plus_n k
  )

let bignum_limbs = 24
let bignum_bytes = 4 * bignum_limbs
let bignum_bits = 8 * bignum_bytes

let uint32_array_of_bigint n =
  let n = Bigint.to_zarith_bigint n in
  let uint32_of_bits bs =
    let open Unsigned.UInt32 in
    let (_, acc) =
      List.fold bs ~init:(one, zero) ~f:(fun (pt, acc) b ->
        let open Infix in
        (pt + pt, if b then acc + pt else acc))
    in
    acc
  in
  List.groupi ~break:(fun i _ _ -> 0 = i mod 32)
    (List.init bignum_bits ~f:(fun i -> Z.testbit n i))
  |> List.map ~f:uint32_of_bits
  |> Array.of_list

let bigint_of_uint32_array arr =
  let open Bigint in
  let b32 = of_int (Int.pow 2 32) in
  let (_, acc) =
    Array.fold arr ~init:(one, zero) ~f:(fun (shift, acc) c ->
      ( shift * b32
      , acc
        + of_int (Unsigned.UInt32.to_int c) * shift))
  in
  acc

let add x y =
  let bigint_typ = Typ.Array Typ.Scalar.Uint32 in
  let result = Array.init bignum_limbs ~f:(fun _ -> Unsigned.UInt32.zero) in
  let x = uint32_array_of_bigint x in
  let y = uint32_array_of_bigint y in
  let _ =
    Interpreter.eval Interpreter.State.empty begin
      let%bind carry_pointer = create_pointer Typ.Scalar.Uint32 "carry_pointer" in
      let%bind x = constant bigint_typ x
      and y = constant bigint_typ y
      and r = constant bigint_typ result
      in
      bigint_add ~carry_pointer
        (Unsigned.UInt32.of_int bignum_limbs) r x y 
    end
  in
  bigint_of_uint32_array result

let sub x y =
  let bigint_typ = Typ.Array Typ.Scalar.Uint32 in
  let result = Array.init bignum_limbs ~f:(fun _ -> Unsigned.UInt32.zero) in
  let x = uint32_array_of_bigint x in
  let y = uint32_array_of_bigint y in
  let _ =
    Interpreter.eval Interpreter.State.empty begin
      let%bind carry_pointer = create_pointer Typ.Scalar.Uint32 "carry_pointer" in
      let%bind x = constant bigint_typ x
      and y = constant bigint_typ y
      and r = constant bigint_typ result
      in
      bigint_sub
        ~carry_pointer
        (Unsigned.UInt32.of_int bignum_limbs) r x y 
    end
  in
  bigint_of_uint32_array result

let add_mod ~p x y =
  let bigint_typ = Typ.Array Typ.Scalar.Uint32 in
  let result = Array.init bignum_limbs ~f:(fun _ -> Unsigned.UInt32.zero) in
  let x = uint32_array_of_bigint x in
  let y = uint32_array_of_bigint y in
  let p = uint32_array_of_bigint p in
  let _ =
    Interpreter.eval Interpreter.State.empty begin
      let%bind x = constant bigint_typ x
      and y = constant bigint_typ y
      and p = constant bigint_typ p
      and r = constant bigint_typ result
      in
      bigint_add_mod ~p
        (Unsigned.UInt32.of_int bignum_limbs) r x y 
    end
  in
  bigint_of_uint32_array result

let sub_mod ~p x y =
  let bigint_typ = Typ.Array Typ.Scalar.Uint32 in
  let result = Array.init bignum_limbs ~f:(fun _ -> Unsigned.UInt32.zero) in
  let x = uint32_array_of_bigint x in
  let y = uint32_array_of_bigint y in
  let p = uint32_array_of_bigint p in
  let _ =
    Interpreter.eval Interpreter.State.empty begin
      let%bind x = constant bigint_typ x
      and y = constant bigint_typ y
      and p = constant bigint_typ p
      and r = constant bigint_typ result
      in
      bigint_sub_mod ~p
        (Unsigned.UInt32.of_int bignum_limbs) r x y 
    end
  in
  bigint_of_uint32_array result

let mul x y =
  let bigint_typ = Typ.Array Typ.Scalar.Uint32 in
  let result = Array.init (2*bignum_limbs) ~f:(fun _ -> Unsigned.UInt32.zero) in
  let x = uint32_array_of_bigint x in
  let y = uint32_array_of_bigint y in
  let _ =
    Interpreter.eval Interpreter.State.empty begin
      let%bind x = constant bigint_typ x ~label:"xs"
      and y = constant bigint_typ y ~label:"ys"
      and r = constant bigint_typ result ~label:"result"
      in
      bigint_mul (Unsigned.UInt32.of_int bignum_limbs)
        r x y 
    end
  in
  bigint_of_uint32_array result

let () =
  let gen = 
    let max_int = Bigint.(pow (of_int 2) (of_int bignum_bits) - one) in
    let open Quickcheck.Let_syntax in
    let%bind p =
      (* Need:
          2*p > 2^bignum_bits
          p < 2^bignum_bits

         I.e.,
         2^(bignum_bits - 1) < p < 2^bignum_bits
         2^(bignum_bits - 1) < p < 2^bignum_bits
      *)
      Bigint.(
        gen_incl
          (pow (of_int 2) (of_int (Int.(-) bignum_bits 1)) + one)
          max_int)
    in
    let%bind x = Bigint.(gen_incl zero max_int) in
    let%map y = Bigint.(gen_incl zero max_int) in
    (x, y, p)
  in
  Quickcheck.test gen
    ~f:(fun (x, y, p) ->
      let r = Bigint.(%) (add_mod ~p x y) p in
      let actual = Bigint.((x + y) % p) in
      if not (Bigint.equal r actual)
      then failwithf !"(%{sexp:Bigint.t} +_p %{sexp:Bigint.t}): got %{sexp:Bigint.t}, expected %{sexp:Bigint.t}"
             x y r actual ())

let () =
  let gen = 
    let max_int = Bigint.(pow (of_int 2) (of_int bignum_bits) - one) in
    let open Quickcheck.Let_syntax in
    let%bind p =
      (* Need:
          2*p > 2^bignum_bits
          p < 2^bignum_bits

         I.e.,
         2^(bignum_bits - 1) < p < 2^bignum_bits
         2^(bignum_bits - 1) < p < 2^bignum_bits
      *)
      Bigint.(
        gen_incl
          (pow (of_int 2) (of_int (Int.(-) bignum_bits 1)) + one)
          max_int)
    in
    let%bind x = Bigint.(gen_incl zero max_int) in
    let%map y = Bigint.(gen_incl zero max_int) in
    (x, y, p)
  in
  Quickcheck.test gen
    ~f:(fun (x, y, p) ->
      let r = Bigint.(%) (sub_mod ~p x y) p in
      let actual = Bigint.((x - y) % p) in
      if not (Bigint.equal r actual)
      then failwithf !"(%{sexp:Bigint.t} -_p %{sexp:Bigint.t}): got %{sexp:Bigint.t}, expected %{sexp:Bigint.t}"
             x y r actual ())

let () =
  let gen = 
    let max_int = Bigint.(pow (of_int 2) (of_int bignum_bits) - one) in
    let open Quickcheck.Let_syntax in
    let%bind x = Bigint.(gen_incl zero max_int) in
    let%map y = Bigint.(gen_incl zero x) in
    (x, y)
  in
  Quickcheck.test gen
    ~f:(fun (x, y) ->
      let r = sub x y in
      let actual = Bigint.( - ) x y in
      if not (Bigint.equal r actual)
      then failwithf !"(%{sexp:Bigint.t} - %{sexp:Bigint.t}): got %{sexp:Bigint.t}, expected %{sexp:Bigint.t}"
             x y r actual ())

let () =
  let g = 
    Bigint.(gen_incl zero (pow (of_int 2) (of_int bignum_bits) - one))
  in
  Quickcheck.test 
    (Quickcheck.Generator.tuple2 g g)
    ~f:(fun (x, y) ->
      let r = mul x y in
      let actual = Bigint.( * ) x y in
      if not (Bigint.equal r actual)
      then failwithf !"(%{sexp:Bigint.t} * %{sexp:Bigint.t}): got %{sexp:Bigint.t}, expected %{sexp:Bigint.t}"
             x y r actual ())

let () =
  let g = 
    (* TODO: This actually fails for now since I don't hold onto the last carry.
       It works for things with no overflow though. *)
    Bigint.(gen_incl zero (pow (of_int 2) (of_int Int.(32*(bignum_limbs - one)))))
  in
  Quickcheck.test 
    (Quickcheck.Generator.tuple2 g g)
    ~f:(fun (x, y) ->
      assert (Bigint.equal (add x y) (Bigint.(+) x y)))

