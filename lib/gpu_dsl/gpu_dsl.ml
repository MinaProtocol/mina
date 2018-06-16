open Core
open Unsigned

(* kernel inputs:

   - specialization constants (compile time constants)
   - push constants (can be changed for each batch of invocations) (e.g., how many times should a loop be performed)
   - "input"/"output" buffers: (have a list of them)
      - Each gets a descriptor set
   (input and output locations)
*)

module Pointer = struct
  type 'a t = Pointer
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

  let pointer_elt : type a. a Pointer.t t -> a t = function
    | Pointer scalar -> Scalar scalar
    | Scalar _ -> assert false

  let array_elt : type a. a array t -> a t = function
    | Array scalar -> Scalar scalar
    | Scalar _ -> assert false

  let equality : type a b. a t -> b t -> (a, b) Type_equal.t option =
    fun x y ->
      match x, y with
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

module Value = struct
  type t =
    | T : 'a Typ.t * 'a -> t

  let sexp_of_t (T (typ, x)) =
    let open Typ in
    let open Scalar in
    match typ with
    | Pointer _ -> Sexp.of_string "Pointer"
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

module Id = struct
  type 'a t =
    | Id : 'a Typ.t * string -> 'a t
    | Constant : 'a Typ.t * 'a -> 'a t

  let sexp_of_t = function
    | Id (_, lab) -> 
      Sexp.List [ Atom "Id"; List [Atom "<opaque>"; Atom lab]]
    | Constant (typ, x) ->
      Sexp.List [Atom "Constant"; Value.sexp_of_t (T (typ, x))]

  let typ = function
    | Id (typ, _) -> typ
    | Constant (typ, _) -> typ

  let label = function
    | Id (_, s) -> s
    | _ -> failwith "label: Constant"

  let constant typ x = Constant (typ, x)
end

module Ctx : sig
  type t
end = struct
  type t = Todo
end

module Op = struct
  (* First arg is the result *)
  module Value = struct
    type 'a op =
      | Or : bool Id.t * bool Id.t -> bool op
      | Add : uint32 Id.t * uint32 Id.t -> uint32 op
      | Less_than : uint32 Id.t * uint32 Id.t -> bool op
      | Array_get : 'b array Id.t * uint32 Id.t -> 'b op

    type 'a t = { op : 'a op; label : string }
  end

  module Action = struct
    type t =
      | Array_set : 'b array Id.t * uint32 Id.t * 'b Id.t -> t
      | Store : 'a Pointer.t Id.t * 'a Id.t -> t
  end
end

module T = struct
  type 'a t =
    | Create_pointer
      : 'c Typ.Scalar.t * string
        * ('c Pointer.t Id.t -> 'b t) ->  'b t
    | Load : 'c Pointer.t Id.t * string * ('c Id.t -> 'a t) -> 'a t
    | Value_op : 'a Op.Value.t * ('a Id.t -> 'b t) -> 'b t
    | Action_op of Op.Action.t * (unit -> 'a t)
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
    | Pure x -> Pure (f x)
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
      | Pure x -> f x
      | Create_pointer (typ, s, k) ->
        Create_pointer (typ, s, fun v -> bind (k v) ~f)
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

  let array_get label arr i =
    Value_op ({ op = Array_get (arr, i); label }, return)

  let do_value op label = Value_op ({ op; label }, return)
  let do_ op = Action_op (op, fun () -> return ())
end

include Monad.Make(struct
    include T
    let map = `Custom map
  end)

module Interpreter = struct
  module State = struct
    type t =
      { bindings : Value.t String.Map.t
      ; used_names : String.Set.t
      }
    [@@deriving sexp_of]

    let empty =
      { bindings = String.Map.empty
      ; used_names = String.Set.empty 
      }

    let get_lab_exn { bindings; _ } lab typ =
      match String.Map.find bindings lab with
      | None -> failwithf "get_lab_exn: %s" lab ()
      | Some v ->
        Option.value_exn (Value.conv v typ)

    let get_exn (type a) s (v : a Id.t) : a =
      match v with
      | Id.Id (typ, lab) ->
        get_lab_exn s lab typ
      | Id.Constant (_, x) -> x

    let set_exn (type a) s (v : a Id.t) (x : a) =
      match v with
      | Id.Constant _ -> failwith "Cannot set a constant"
      | Id.Id (typ, lab) ->
        { s with
          bindings = Map.set ~key:lab ~data:(Value.T (typ, x)) s.bindings }
  end

  let eval_op (type a) (s : State.t) ({op; label} : a Op.Value.t) : State.t * a Id.t =
    let open Op.Value in
    match op with
    | Add (x, y) ->
      let x = State.get_exn s x in
      let y = State.get_exn s y in
      let id = Id.Id (Typ.uint32, label) in
      (State.set_exn s id (Unsigned.UInt32.add x y), id)
    | Or (x, y) ->
      let x = State.get_exn s x in
      let y = State.get_exn s y in
      let id = Id.Id (Typ.bool, label) in
      (State.set_exn s id (x || y), id)
    | Less_than (x, y) ->
      let x = State.get_exn s x in
      let y = State.get_exn s y in
      let id = Id.Id (Typ.bool, label) in
      (State.set_exn s id (Unsigned.UInt32.compare x y < 0), id)
    | Array_get (arr_id, i) ->
      let arr = State.get_exn s arr_id in
      let i = State.get_exn s i in
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
      let id = ptr_value_id ptr in
      State.set_exn s id (State.get_exn s value)

    | Array_set (arr, i, elt) ->
      let arr = State.get_exn s arr in
      let i = State.get_exn s i in
      let elt = State.get_exn s elt in
      arr.(Unsigned.UInt32.to_int i) <- elt;
      s

  let rec eval : type a. State.t -> a T.t -> State.t * a =
    fun s t ->
      let open T in
      match t with
      | Pure x -> (s, x)
      | Load (ptr, lab, k) ->
        let value = State.get_exn s (ptr_value_id ptr) in 
        let typ =
          match Id.typ ptr with
          | Typ.Pointer t -> Typ.Scalar t
          | _ -> assert false
        in
        eval s (k (Id.constant typ value))
      | Create_pointer (typ, lab, k) ->
        if Set.mem s.used_names lab
        then failwithf "Name %s already in use" lab ()
        else
          let id = Id.Id (Typ.Pointer typ, lab) in
          eval
            {s with used_names = Set.add s.used_names lab}
            (k id)
      | Phi (_, k) -> eval s (k ())
      | For { range=(a, b); closure=_; body; after } ->
        let a = Unsigned.UInt32.to_int (State.get_exn s a) in
        let b = Unsigned.UInt32.to_int (State.get_exn s b) in
        let rec go s i =
          if i > b
          then eval s (after ())
          else
            let (s', ()) =
              eval s
                (body (Id.constant Typ.uint32 (Unsigned.UInt32.of_int i)))
            in
            go s' (i + 1)
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
        let value =
          if cond
          then State.get_exn s then_
          else State.get_exn s else_
        in
        eval s (after (Id.constant (Id.typ then_) value))
      | Do_if { cond; then_; after } ->
        let cond = State.get_exn s cond in
        if cond
        then
          let (s, ()) = eval s then_ in
          eval s (after ())
        else eval s (after ())
end

include T
open Let_syntax

let array_get label xs i =
  let open Op.Value in
  do_value (Array_get (xs, i)) label

let array_set xs i x =
  do_ (Array_set (xs, i, x))

let add lab x y = do_value (Add (x, y)) lab

let less_than lab x y = do_value (Less_than (x, y)) lab

let add_bool lab x b =
  let one = Id.constant Typ.uint32 Unsigned.UInt32.one in
  let zero = Id.constant Typ.uint32 Unsigned.UInt32.zero in
  let%bind n = if_ b ~then_:one ~else_:zero in
  add lab x n

let create_pointer typ label =
  Create_pointer (typ, label, return)

let load ptr label =
  Load (ptr, label, return)

let store ptr value =
  Action_op (Op.Action.Store (ptr, value), return)

let or_ x y lab = do_value (Or (x, y)) lab

let add n rs xs ys =
  let%bind carryp = create_pointer Typ.Scalar.Bool "carryp" in
  let%bind () = store carryp (Id.constant Typ.bool false) in
  let start = Id.constant Typ.uint32 Unsigned.UInt32.zero in
  let stop = Id.constant Typ.uint32 Unsigned.UInt32.(sub n one) in
  for_ (start, stop) (fun i ->
    let%bind x = array_get "x" xs i
    and y = array_get "y" ys i
    in
    let%bind x_plus_y = add "x_plus_y" x y in
    let%bind c = less_than "c" x_plus_y x in
    let%bind carry = load carryp "carry" in
    let%bind x_plus_y_with_prev_carry =
      add_bool "x_plus_y_with_prev_carry" x_plus_y carry
    in
    let%bind d = less_than "d" x_plus_y_with_prev_carry x_plus_y in
    let%bind () =
      let%bind new_carry = or_ c d "new_carry" in
      store carryp new_carry
    in
    array_set rs i x_plus_y_with_prev_carry
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
  let b32 = of_int 32 in
  let (_, acc) =
    Array.fold arr ~init:(one, zero) ~f:(fun (shift, acc) c ->
      (shift * b32, acc + of_int (Unsigned.UInt32.to_int c) * shift))
  in
  acc

let add x y =
  let c x =
    Id.constant (Array Typ.Scalar.Uint32) x
  in
  let result = Array.init bignum_limbs ~f:(fun _ -> Unsigned.UInt32.zero) in
  let x = c (uint32_array_of_bigint x) in
  let y = c (uint32_array_of_bigint y) in
  let _ =
    Interpreter.eval Interpreter.State.empty
      (add
        (Unsigned.UInt32.of_int bignum_limbs)
        (c result)
        x
        y)
  in
  bigint_of_uint32_array result

let () =
  let g = 
    Bigint.(gen_incl zero (pow (of_int 2) (of_int 31) - one))
  in
  Quickcheck.test 
    (Quickcheck.Generator.tuple2 g g)
    ~f:(fun (x, y) ->
      assert (Bigint.equal (add x y) (Bigint.(+) x y)))

let () =
  let open Bigint in
  printf !"%{sexp:Bigint.t}\n%!"
    (add (of_int 123) (of_int 456))

