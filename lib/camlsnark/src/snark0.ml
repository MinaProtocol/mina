open Core
open Ctypes

let () = Camlsnark_c.linkme

module Restrict_monad2 (M : Monad.S2)(T : sig type t end)
  : Monad.S with type 'a t = ('a, T.t) M.t
= struct
  type 'a t = ('a, T.t) M.t
  let map = M.map
  let bind = M.bind
  let return = M.return
  let all = M.all
  let all_ignore = M.all_ignore
  let ignore_m = M.ignore_m
  let join = M.join
  module Let_syntax = M.Let_syntax
  module Monad_infix = M.Monad_infix
  include Monad_infix
end

module Make (Backend : Backend_intf.S) = struct
open Backend

module R1CS_constraint_system = R1CS_constraint_system

module Bigint = Bigint.R

module Field = struct
  include Field

  let inv x = if equal x zero then failwith "Field.inv: zero" else inv x

  (* TODO: Optimize *)
  let div x y = mul x (inv y)

  let negate x = sub zero x

  let unpack x =
    let n = Bigint.of_field x in
    List.init size_in_bits ~f:(fun i -> Bigint.test_bit n i)
  ;;

  let pack =
    let rec go x acc = function
      | [] -> acc
      | b :: bs ->
        go (Field.add x x) (if b then Field.add acc x else acc) bs
    in
    fun bs -> go Field.one Field.zero bs

  let to_string x =
    let n = Bigint.of_field x in
    String.init Field.size_in_bits ~f:(fun i ->
      if Bigint.test_bit n i then '1' else '0')

  let of_string_exn s =
    let (_two_to_the_n, acc) =
      String.fold s ~init:(one, zero)  ~f:(fun (two_to_the_i, acc) c ->
        let pt = add two_to_the_i two_to_the_i in
        match c with
        | '0' -> (pt, acc)
        | '1' -> (pt, add acc two_to_the_i)
        | _ -> failwith "Field.of_string_exn: Got non 0-1 character.")
    in
    acc

  let sexp_of_t x = String.sexp_of_t (to_string x)
  let t_of_sexp s = of_string_exn (String.t_of_sexp s)

  module Infix = struct
    let (+) = add
    let ( * ) = mul
    let (-) = sub
    let (/) = div
  end
end
module Proof = Proof
module Keypair = Keypair
module Verification_key = Verification_key
module Proving_key = Proving_key

module Var = struct
  module T = struct
    include Backend.Var
    let compare x y = Int.compare (index x) (index y)
    let hash x = Int.hash (Var.index x)
    let t_of_sexp _ = failwith "Var.t_of_sexp"
    let sexp_of_t v =
      Sexp.(List [Atom "var"; Atom (Int.to_string (index v))])
  end

  include T
  include Comparable.Make(T)
end

module Cvar = struct
  include Cvar.Make(Field)(Var)

  let var_indices t =
    let (_, terms) = to_constant_and_terms t in
    List.map ~f:(fun (_, v) -> Var.index v) terms
  ;;
end

module Linear_combination = struct
  open Backend.Linear_combination

  type t = Backend.Linear_combination.t

  let of_constant = function
    | None -> Linear_combination.create ()
    | Some c -> Linear_combination.of_field c
  ;;

  let of_var (cv : Cvar.t) =
    let (constant, terms) = Cvar.to_constant_and_terms cv in
    let t = of_constant constant in
    List.iter terms ~f:(fun (c, v) ->
      Linear_combination.add_term t c v);
    t
  ;;

  (* TODO: Could be more efficient. *)
  let of_terms terms =
    of_var (Cvar.linear_combination terms)
  ;;

  let of_field = Backend.Linear_combination.of_field
  let one = of_field Field.one
  let zero = of_field Field.zero
end

module Constraint = struct
  type basic =
    | Boolean of Cvar.t
    | Equal of Cvar.t * Cvar.t
    | R1CS of Cvar.t * Cvar.t * Cvar.t

  type 'k with_constraint_args = ?label:string -> 'k

  type basic_with_annotation =
    { basic : basic; annotation : string option }

  type t = basic_with_annotation list

  let basic_to_r1cs_constraint : basic -> R1CS_constraint.t =
    let of_var = Linear_combination.of_var in
    function
    | Boolean v ->
      let lc = of_var v in
      R1CS_constraint.create lc lc lc
    | Equal (v1, v2) ->
      R1CS_constraint.create
        Linear_combination.one
        (of_var v1)
        (of_var v2)
    | R1CS (a, b, c) ->
      R1CS_constraint.create (of_var a) (of_var b) (of_var c)
  ;;

  let create_basic ?label basic = { basic; annotation = label }
  ;;

  let override_label { basic; annotation=a } label_opt =
    { basic; annotation = match label_opt with Some x -> Some x | None -> a }
  ;;

  let equal ?label x y = [ create_basic ?label (Equal (x, y)) ]
  let boolean ?label x = [ create_basic ?label (Boolean x) ]
  let r1cs ?label a b c = [ create_basic ?label (R1CS (a, b, c)) ]

  let stack_to_string =
    String.concat ~sep:"\n"
  ;;

  let add ~stack (t : t) system =
    List.iter t ~f:(fun { basic; annotation } ->
      let label = Option.value annotation ~default:"<unknown>" in
      let c = basic_to_r1cs_constraint basic in
      R1CS_constraint_system.add_constraint_with_annotation system c
        (stack_to_string (label :: stack)))
  ;;
end

module Var_spec_monads = struct
  module Store = struct
    module T = struct
      type 'k t =
        | Store of Field.t * (Backend.Var.t -> 'k)

      let map t ~f =
        match t with
        | Store (x, k) -> Store (x, fun v -> f (k v))
      ;;
    end

    include Free_monad.Make(T)

    let store x =
      Free (T.Store (x, fun v -> Pure (Cvar.Unsafe.of_var v)))
    ;;

    let rec run t f =
      match t with
      | Pure x -> x
      | Free (T.Store (x, k)) ->
        run (k (f x)) f
    ;;
  end

  module Read = struct
    module T = struct
      type 'k t =
        | Read of Cvar.t * (Field.t -> 'k)

      let map t ~f =
        match t with
        | Read (v, k) -> Read (v, fun x -> f (k x))
    end

    include Free_monad.Make(T)

    let read v = Free (T.Read (v, return))

    let rec run t f =
      match t with
      | Pure x -> x
      | Free (T.Read (x, k)) ->
        run (k (f x)) f
    ;;
  end

  module Alloc = struct
    module T = struct
      type 'k t =
        | Alloc of (Backend.Var.t -> 'k)

      let map t ~f =
        match t with
        | Alloc k -> Alloc (fun v -> f (k v))
      ;;
    end

    include Free_monad.Make(T)

    let alloc = Free (T.Alloc (fun v -> Pure (Cvar.Unsafe.of_var v)))

    let rec run t f =
      match t with
      | Pure x -> x
      | Free (T.Alloc k) ->
        run (k (f ())) f
    ;;

    let size t =
      let dummy = Backend.Var.create 0 in
      let rec go acc = function
        | Pure _ -> acc
        | Free (T.Alloc k) ->
          go (acc + 1) (k dummy)
      in
      go 0 t
  end
end

module Handle0 = struct
  type ('var, 'value) t =
    { var : 'var
    ; value : 'value option
    }
end

module As_prover0 = struct
  type ('a, 's) t = (Cvar.t -> Field.t) -> 's -> ('s * 'a)
end

module rec Var_spec0 : sig
  open Var_spec_monads

  type ('var, 'value) t =
    { store : 'value -> 'var Store.t
    ; read  : 'var -> 'value Read.t
    ; alloc : 'var Alloc.t
    ; check : 'var -> (unit, unit) Checked0.t
    }
end = Var_spec0
and Checked0 : sig
  (* TODO-someday: Consider having an "Assembly" type with only a store constructor for straight up Var.t's
    that this gets compiled into. *)
  type ('a, 's) t =
    | Pure : 'a -> ('a, 's) t
    | Add_constraint : Constraint.t * ('a, 's) t -> ('a, 's) t
    | With_constraint_system : (R1CS_constraint_system.t -> unit) * ('a, 's) t -> ('a, 's) t
    | With_label : string * ('a, 's) t * ('a -> ('b, 's) t) -> ('b, 's) t
    | With_state
      : ('s1, 's) As_prover0.t
        * ('s1 -> (unit, 's) As_prover0.t)
        * ('b, 's1) t
        * ('b -> ('a, 's) t) -> ('a, 's) t
    | As_prover : (unit, 's) As_prover0.t  * ('a, 's) t -> ('a, 's) t
    | Store
      : ('var, 'value) Var_spec0.t * ('value, 's) As_prover0.t
        * (('var, 'value) Handle0.t -> ('a, 's) t) -> ('a, 's) t
    | Next_auxiliary : (int -> ('a, 's) t) -> ('a, 's) t
end = Checked0

module Checked1 = struct
  module T = struct
    include Checked0
    let return x = Pure x

    let as_prover x = As_prover (x, return ())

    let rec map : type s a b. (a, s) t -> f:(a -> b) -> (b, s) t =
      fun t ~f ->
        match t with
        | Pure x -> Pure (f x)
        | With_label (s, t, k) -> With_label (s, t, fun b -> map (k b) ~f)
        | With_constraint_system (c, k) -> With_constraint_system (c, map k ~f)
        | As_prover (x, k) -> As_prover (x, map k ~f)
        | Add_constraint (c, t1) -> Add_constraint (c, map t1 ~f)
        | With_state (p, and_then, t_sub, k) -> With_state (p, and_then, t_sub, fun b -> map (k b) ~f)
        | Store (spec, c, k) -> Store (spec, c, fun v -> map (k v) ~f)
        | Next_auxiliary k -> Next_auxiliary (fun x -> map (k x) ~f)
    ;;

    let map = `Custom map

    let rec bind : type s a b. (a, s) t -> f:(a -> (b, s) t) -> (b, s) t =
      fun t ~f ->
        match t with
        | Pure x -> f x
        | With_label (s, t, k) -> With_label (s, t, fun b -> bind (k b) ~f)
        | With_constraint_system (c, k) -> With_constraint_system (c, bind k ~f)
        | As_prover (x, k) -> As_prover (x, bind k ~f)
        (* Someday: This case is probably a performance bug *)
        | Add_constraint (c, t1) -> Add_constraint (c, bind t1 ~f)
        | With_state (p, and_then, t_sub, k) -> With_state (p, and_then, t_sub, fun b -> bind (k b) ~f)
        | Store (spec, c, k) -> Store (spec, c, fun v -> bind (k v) ~f)
        | Next_auxiliary k -> Next_auxiliary (fun x -> bind (k x) ~f)
    ;;
  end
  include T
  include Monad.Make2(T)
end

module Var_spec = struct
  include Var_spec_monads
  include Var_spec0

  type ('var, 'value) var_spec = ('var, 'value) t

  module Data_spec = struct
    type ('r_var, 'r_value, 'k_var, 'k_value) t =
      | (::)
        : ('var, 'value) var_spec
          * ('r_var, 'r_value, 'k_var, 'k_value) t
        -> ('r_var, 'r_value, 'var -> 'k_var, 'value -> 'k_value) t
      | [] : ('r_var, 'r_value, 'r_var, 'r_value) t

    let size t =
      let rec go
        : type r_var r_value k_var k_value.
          int -> (r_var, r_value, k_var, k_value) t -> int
        =
        fun acc t ->
          match t with
          | [] -> acc
          | { alloc; _ } :: t' ->
            go (acc + Alloc.size alloc) t'
      in
      go 0 t
  end

  let store ({ store; _ } : ('var, 'value) t) (x : 'value) : 'var Store.t = store x
  ;;

  let read ({ read; _ } : ('var, 'value) t) (v : 'var) : 'value Read.t = read v
  ;;

  let alloc ({ alloc; _ } : ('var, 'value) t) : 'var Alloc.t = alloc
  ;;

  let check ({ check; _ } : ('var, 'value) t) (v : 'var) : (unit, 's) Checked1.t =
    let do_nothing : (unit, _) As_prover0.t = fun _ s -> (s, ()) in
    Checked1.With_state (do_nothing, (fun () -> do_nothing), check v, Checked1.return)
  ;;

  let field : (Cvar.t, Field.t) t =
    { store = Store.store
    ; read = Read.read
    ; alloc = Alloc.alloc
    ; check = fun _ -> Checked1.return ()
    }

  let hlist (type k_var) (type k_value)
        (spec0 : (unit, unit, k_var, k_value) Data_spec.t)
    : ((unit, k_var) H_list.t, (unit, k_value) H_list.t) t
    =
    let store xs0 : _ Store.t =
      let rec go
        : type k_var k_value.
          (unit, unit, k_var, k_value) Data_spec.t
          -> (unit, k_value) H_list.t
          -> (unit, k_var) H_list.t Store.t
        =
        fun spec0 xs0 ->
          let open Data_spec in
          let open H_list in
          match spec0, xs0 with
          | [], [] ->
            Store.return H_list.[]
          | s :: spec, x :: xs ->
            let open Store.Let_syntax in
            let%map y = store s x
            and ys = go spec xs
            in
            (y :: ys)
      in
      go spec0 xs0
    in
    let read xs0 : (unit, k_value) H_list.t Read.t =
      let rec go
        : type k_var k_value.
          (unit, unit, k_var, k_value) Data_spec.t
          -> (unit, k_var) H_list.t
          -> (unit, k_value) H_list.t Read.t
        =
        fun spec0 xs0 ->
          let open Data_spec in
          let open H_list in
          match spec0, xs0 with
          | [], [] ->
            Read.return H_list.[]
          | s :: spec, x :: xs ->
            let open Read.Let_syntax in
            let%map y = read s x
            and ys = go spec xs
            in
            (y :: ys)
      in
      go spec0 xs0
    in
    let alloc : _ Alloc.t =
      let rec go
        : type k_var k_value.
          (unit, unit, k_var, k_value) Data_spec.t
          -> (unit, k_var) H_list.t Alloc.t
        =
        fun spec0 ->
          let open Data_spec in
          let open H_list in
          match spec0 with
          | [] ->
            Alloc.return H_list.[]
          | s :: spec ->
            let open Alloc.Let_syntax in
            let%map y = alloc s
            and ys = go spec
            in
            (y :: ys)
      in
      go spec0
    in
    let check xs0 : (unit, unit) Checked1.t =
      let rec go
        : type k_var k_value.
          (unit, unit, k_var, k_value) Data_spec.t
          -> (unit, k_var) H_list.t
          -> (unit, unit) Checked1.t
        =
        fun spec0 xs0 ->
          let open Data_spec in
          let open H_list in
          let open Checked1.Let_syntax in
          match spec0, xs0 with
          | [], [] -> return ()
          | s :: spec, x :: xs ->
            let%map () = check s x
            and () = go spec xs
            in
            ()
      in
      go spec0 xs0
    in
    { read; store; alloc; check }
  ;;

  let transport ({ read; store; alloc; check } : ('var1, 'value1) t)
        ~(there : 'value2 -> 'value1) ~(back : 'value1 -> 'value2)
        : ('var1, 'value2) t
    =
    { alloc
    ; store = (fun x -> store (there x))
    ; read = (fun v -> Read.map ~f:back (read v))
    ; check
    }
  ;;

  (* TODO: Do a CPS style thing instead if it ends up being an issue converting
     back and forth. *)
  let of_hlistable
        (spec : (unit, unit, 'k_var, 'k_value) Data_spec.t)
        ~(var_to_hlist : 'var -> (unit, 'k_var) H_list.t)
        ~(var_of_hlist : (unit, 'k_var) H_list.t -> 'var)
        ~(value_to_hlist : 'value -> (unit, 'k_value) H_list.t)
        ~(value_of_hlist : (unit, 'k_value) H_list.t -> 'value)
    : ('var, 'value) t
    =
    let { read; store; alloc; check } = hlist spec in
    { read = (fun v -> Read.map ~f:value_of_hlist (read (var_to_hlist v)))
    ; store = (fun x -> Store.map ~f:var_of_hlist (store (value_to_hlist x)))
    ; alloc = Alloc.map ~f:var_of_hlist alloc
    ; check = (fun v -> check (var_to_hlist v))
    }
  ;;

  let list ~length ({ read; store; alloc; check } : ('elt_var, 'elt_value) t)
    : ('elt_var list, 'elt_value list) t
    =
    let store ts =
      let n = List.length ts in
      (if n <> length then failwithf "Var_spec.list: Expected length %d, got %d" length n ());
      Store.all (List.map ~f:store ts)
    in
    let alloc = Alloc.all (List.init length (fun _ -> alloc)) in
    let check ts = Checked1.all_ignore (List.map ts ~f:check) in
    let read vs = Read.all (List.map vs ~f:read) in
    { read; store; alloc; check }
  ;;

  (* TODO-someday: Make more efficient *)
  let array ~length ({ read; store; alloc; check } : ('elt_var, 'elt_value) t)
    : ('elt_var array, 'elt_value array) t
    =
    let store ts =
      assert (Array.length ts = length);
      Store.map ~f:Array.of_list (Store.all (List.map ~f:store (Array.to_list ts)))
    in
    let alloc =
      let open Alloc.Let_syntax in
      let%map vs = Alloc.all (List.init length (fun _ -> alloc)) in
      Array.of_list vs
    in
    let read vs =
      assert (Array.length vs = length);
      Read.map ~f:Array.of_list
        (Read.all (List.map ~f:read (Array.to_list vs)))
    in
    let check ts =
      assert (Array.length ts = length);
      let open Checked1.Let_syntax in
      let rec go i =
        if i = length
        then return ()
        else
          let%map () = check ts.(i)
          and () = go (i + 1)
          in
          ()
      in
      go 0
    in
    { read; store; alloc; check }
  ;;

  (* TODO: Assert that a stored value has the same shape as the template. *)
  module Of_traversable (T : Traversable.S) = struct
    let spec ~template ({ read; store; alloc; check } : ('elt_var, 'elt_value) t)
      : ('elt_var T.t, 'elt_value T.t) t
      =
      let traverse_store = let module M = T.Traverse(Store) in M.f in
      let traverse_read = let module M = T.Traverse(Read) in M.f in
      let traverse_alloc = let module M = T.Traverse(Alloc) in M.f in
      let traverse_checked =
        let module M = T.Traverse(Restrict_monad2(Checked1)(struct type t = unit end)) in
        M.f
      in
      let read var = traverse_read var ~f:read in
      let store value = traverse_store value ~f:store in
      let alloc = traverse_alloc template ~f:(fun () -> alloc) in
      let check t = Checked1.map (traverse_checked t ~f:check) ~f:ignore in
      { read; store; alloc; check }
  end

  let tuple2 (spec1 : ('var1, 'value1) t) (spec2 : ('var2, 'value2) t)
      : ('var1 * 'var2, 'value1 * 'value2) t
    =
    let alloc =
      let open Alloc.Let_syntax in
      let%map x = spec1.alloc
      and y = spec2.alloc
      in
      (x, y)
    in
    let read (x, y) =
      let open Read.Let_syntax in
      let%map x = spec1.read x
      and y = spec2.read y
      in
      (x, y)
    in
    let store (x, y) =
      let open Store.Let_syntax in
      let%map x = spec1.store x
      and y = spec2.store y
      in
      (x, y)
    in
    let check (x, y) =
      let open Checked1.Let_syntax in
      let%map () = spec1.check x
      and () = spec2.check y
      in
      ()
    in
    { read; store; alloc; check }
  ;;

  let tuple3
        (spec1 : ('var1, 'value1) t)
        (spec2 : ('var2, 'value2) t)
        (spec3 : ('var3, 'value3) t)
      : ('var1 * 'var2 * 'var3, 'value1 * 'value2 * 'value3) t
    =
    let alloc =
      let open Alloc.Let_syntax in
      let%map x = spec1.alloc
      and y = spec2.alloc
      and z = spec3.alloc
      in
      (x, y, z)
    in
    let read (x, y, z) =
      let open Read.Let_syntax in
      let%map x = spec1.read x
      and y = spec2.read y
      and z = spec3.read z
      in
      (x, y, z)
    in
    let store (x, y, z) =
      let open Store.Let_syntax in
      let%map x = spec1.store x
      and y = spec2.store y
      and z = spec3.store z
      in
      (x, y, z)
    in
    let check (x, y, z) =
      let open Checked1.Let_syntax in
      let%map () = spec1.check x
      and () = spec2.check y
      and () = spec3.check z
      in
      ()
    in
    { read; store; alloc; check }
  ;;
end

module As_prover = struct
  include As_prover0

  let run (t : ('a, 's) t) tbl s : ('s * 'a) = t tbl s

  let map (t : ('a, 's) t) ~(f : 'a -> 'b) : ('b, 's) t =
    fun tbl s ->
      let (s', x) = t tbl s in
      (s', f x)
  ;;

  let bind (t : ('a, 's) t) ~(f : 'a -> ('b, 's) t) : ('b, 's) t =
    fun tbl s ->
      let (s', x) = t tbl s in
      f x tbl s'
  ;;

  let return (x : 'a) : ('a, 's) t =
    fun _ s -> (s, x)
  ;;

  module T = struct
    type nonrec ('a, 's) t = ('a, 's) t
    let map = `Custom map
    let bind = bind
    let return = return
  end
  include Monad.Make2(T)

  let get_state : ('s, 's) t = fun _tbl s -> (s, s)
  ;;

  let read_var (v : Cvar.t) : (Field.t, 's) t = fun tbl s -> (s, tbl v)
  ;;

  let set_state (s : 's) : (unit, 's) t = fun tbl _ -> (s, ())
  ;;

  let modify_state f =
    fun _tbl s -> (f s, ())
  ;;

  let read
        ({ read; _ } : ('var, 'value) Var_spec.t)
        (var : 'var)
    : ('value, 'prover_state) t
    =
    fun tbl s ->
      (s, Var_spec.Read.run (read var) tbl)
  ;;

  type ('a, 'prover_state) as_prover = ('a, 'prover_state) t

  module Array = struct
    include Array

    let map (t : 'a array) ~(f : 'a -> ('b, 's) as_prover) : ('b array, 's) as_prover =
      fun tbl s0 ->
        let s = ref s0 in
        let res =
          Array.map t ~f:(fun x ->
            let (s', y) = f x tbl !s in
            s := s';
            y)
        in
        (!s, res)
    ;;
  end

  module Ref = struct
    type 'a t = 'a option ref

    let create (x : ('a, 's) As_prover0.t) : ('a t, 's) Checked1.t =
      let r = ref None in
      let open Checked1.Let_syntax in
      let%map () = Checked1.as_prover (map x ~f:(fun x -> r := Some x)) in
      r
    ;;

    let get (r : 'a t) =
      fun _tbl s -> (s, Option.value_exn !r)
    ;;

    let set (r : 'a t) x =
      fun _tbl s -> (s, (r := Some x))
    ;;
  end

  let map2 x y ~f =
    let open Let_syntax in
    let%map x = x and y = y in f x y
  ;;
end

module Handle = struct
  include Handle0

  let value (t : ('var, 'value) t) : ('value, 's) As_prover0.t =
    fun _ s -> (s, Option.value_exn t.value)
  ;;

  let var { var; _ } = var
end

module Checked = struct
  include Checked1
  let exists_with_handle
        (spec : ('var, 'value) Var_spec.t)
        (c : ('value, 's) As_prover0.t)
    : (('var, 'value) Handle.t, 's) t
    =
    Store (spec, c, return)
  ;;

  let exists spec c =
    map (exists_with_handle spec c) ~f:Handle.var
  ;;

  let next_auxiliary = Next_auxiliary return

  let with_constraint_system f = With_constraint_system (f, return ())

  let with_label s t = With_label (s, t, return)
  ;;

  let do_nothing _ = As_prover.return ()
  let with_state ?(and_then=do_nothing) f sub =
    With_state (f, and_then, sub, return)

  let assert_ ?label c =
    Add_constraint (List.map c ~f:(fun c -> Constraint.override_label c label), return ())
  ;;

  let assert_r1cs ?label a b c = assert_ (Constraint.r1cs ?label a b c)

  let assert_all =
    let map_concat_rev xss ~f =
      let rec go acc xs xss =
        match xs, xss with
        | [], [] -> acc
        | [], xs :: xss -> go acc xs xss
        | x :: xs, _ -> go (f x :: acc) xs xss
      in
      go [] [] xss
    in
    fun ?label cs ->
      Add_constraint
        (map_concat_rev ~f:(fun c -> Constraint.override_label c label) cs, return ())
  ;;

  let assert_equal ?label x y = assert_ (Constraint.equal ?label x y)

  let time label f =
    let start_time = Time.now () in
    let x = f () in
    let end_time = Time.now () in
    printf "%s: %s\n%!" label Time.(Span.to_string_hum (diff end_time start_time));
    x
  ;;

  (* TODO-someday: Add pass to unify variables which have an Equal constraint *)
  let constraint_system ~num_inputs (t : (unit, 's) t) : R1CS_constraint_system.t =
    let system = R1CS_constraint_system.create () in
    let next_auxiliary = ref (1 + num_inputs) in
    let alloc_var () =
      let v = Backend.Var.create (!next_auxiliary) in
      incr next_auxiliary;
      v
    in
    R1CS_constraint_system.set_primary_input_size system num_inputs;
    let rec go : type a s. string list -> (a, s) t -> a =
      fun stack t0 ->
        match t0 with
        | Pure x -> x
        | With_constraint_system (f, k) ->
          f system;
          go stack k
        | As_prover (_x, k) ->
          go stack k
        | Add_constraint (c, t) ->
          Constraint.add ~stack c system;
          go stack t
        | Next_auxiliary k ->
          go stack (k !next_auxiliary)
        | With_label (s, t, k) ->
          let y = go (s :: stack) t in (* TODO: Not a tail call! *)
          go stack (k y)
        | With_state (_p, _and_then, t_sub, k) ->
          let y = go stack t_sub in (* TODO: Not a tail call! *)
          go stack (k y)
        | Store ({ alloc; check; _ }, _c, k) ->
          let var = Var_spec.Alloc.run alloc alloc_var in
          (* TODO: Push a label onto the stack here *)
          let () = go stack (check var) in (* TODO: Not a tail call! *)
          go stack (k { Handle.var; value = None })
    in
    time "constraint_system" (fun () ->
      go [] t);
    let auxiliary_input_size = !next_auxiliary - (1 + num_inputs) in
    R1CS_constraint_system.set_auxiliary_input_size system auxiliary_input_size;
    system
  ;;

  let auxiliary_input (type s)
        ~num_inputs
        (t0 : (unit, s) t) (s0 : s)
        (input : Field.Vector.t)
    : Field.Vector.t =
    let next_auxiliary = ref (1 + num_inputs) in
    let aux = Field.Vector.create () in
    let get_value : Cvar.t -> Field.t =
      let get_one v =
        let i = Backend.Var.index v in
        if i <= num_inputs
        then Field.Vector.get input (i - 1)
        else Field.Vector.get aux (i - num_inputs - 1)
      in
      Cvar.eval get_one
    in
    let store_field_elt x =
      let v = Backend.Var.create (!next_auxiliary) in
      incr next_auxiliary;
      Field.Vector.emplace_back aux x;
      v
    in
    let rec go : type a s. (a, s) t -> s -> s * a =
      fun t s ->
        match t with
        | Pure x -> (s, x)
        | With_constraint_system (_, k) ->
          go k s
        | With_label (_, t, k) ->
          let (s', y) = go t s in
          go (k y) s'
        | As_prover (x, k) ->
          let (s', ()) = As_prover.run x get_value s in
          go k s'
        | Add_constraint (_c, t) ->
          go t s
        | With_state (p, and_then, t_sub, k) ->
          let (s, s_sub) = As_prover.run p get_value s in
          let (s_sub, y) = go t_sub s_sub in
          let (s, ()) = As_prover.run (and_then s_sub) get_value s in
          go (k y) s
        | Store ({ store; check; _ }, c, k) ->
          let (s', value) = As_prover.run c get_value s in
          let var =
            Var_spec.Store.run (store value) store_field_elt
          in
          let ((), ()) = go (check var) () in
          go (k { Handle.var; value = Some value }) s'
        | Next_auxiliary k ->
          go (k !next_auxiliary) s
    in
    time "auxiliary_input" (fun () ->
      ignore (go t0 s0));
    aux
  ;;

  let equal (x : Cvar.t) (y : Cvar.t) : (Cvar.t, _) t =
    let open Let_syntax in
    let%bind inv = exists Var_spec.field begin
      let open As_prover.Let_syntax in
      let%map x = As_prover.read_var x
      and y     = As_prover.read_var y
      in
      if Field.equal x y then Field.zero else Field.inv (Field.sub x y)
    end
    and r = exists Var_spec.field begin
      let open As_prover.Let_syntax in
      let%map x = As_prover.read_var x
      and y     = As_prover.read_var y
      in
      if Field.equal x y then Field.one else Field.zero
    end
    in
    let%map () =
      let open Constraint in
      let open Cvar.Infix in
      assert_all
        [ r1cs ~label:"equals_1"
            inv
            (x - y)
            (Cvar.constant Field.one - r)
        ; r1cs ~label:"equals_2"
            r
            (x - y)
            (Cvar.constant Field.zero)
        ]
    in
    r
  ;;

  let mul x y =
    with_label "Checked.mul" begin
      let open Let_syntax in
      let%bind z =
        exists Var_spec.field begin
          let open As_prover.Let_syntax in
          let%map x = As_prover.read_var x
          and y     = As_prover.read_var y
          in
          Field.mul x y
        end
      in
      let%map () = assert_r1cs x y z in
      z
    end
  ;;

  let div x y =
    with_label "Checked.div" begin
      let open Let_syntax in
      let%bind z =
        exists Var_spec.field begin
          let open As_prover.Let_syntax in
          let%map x = As_prover.read_var x
          and y     = As_prover.read_var y
          in
          Field.div x y
        end
      in
      let%map () = assert_r1cs y z x in
      z
    end
  ;;

  let inv x =
    with_label "Checked.inv" begin
      let open Let_syntax in
      let%bind x_inv = exists Var_spec.field As_prover.(map ~f:Field.inv (read_var x)) in
      let%map () = assert_r1cs ~label:"field_inverse" x x_inv (Cvar.constant Field.one) in
      x_inv
    end
  ;;

  module Boolean = struct
    type var = Cvar.t
    type value = bool

    let true_ : var = Cvar.constant Field.one
    let false_ : var = Cvar.constant Field.zero

    let not (x : var) : var = Cvar.Infix.(true_  - x)

    let (&&) : var -> var -> (var, _) t = mul

    let any : var list -> (var, _) Checked1.t = function
      | [] -> return false_
      | bs ->
        with_label "Checked.any" begin
          let open Let_syntax in
          let%map all_zero =
            equal (Cvar.sum (bs :> Cvar.t list)) (Cvar.constant Field.zero)
          in
          not all_zero
        end
    ;;

    let (||) x y =
      let open Let_syntax in
      let%map both_false = not x && not y in
      not both_false
    ;;

    let all =
      let open Let_syntax in
      let rec go acc = function
        | [] -> return acc
        | b :: bs ->
          let%bind acc = b && acc in
          go acc bs
      in
      function
      | [] -> return true_
      | b :: bs -> with_label "Checked.all" (go b bs)
    ;;

    let var_of_value b =
      if b then true_ else false_

    module Unsafe = struct
      let of_cvar (t : Cvar.t) : var = t
    end

    let spec : (var, value) Var_spec.t =
      let open Var_spec in
      let store b = Store.store (if b then Field.one else Field.zero) in
      let read v =
        let open Read.Let_syntax in
        let%map x = Read.read v in
        if Field.equal x Field.one
        then true
        else if Field.equal x Field.zero
        then false
        else failwith "Boolean.spec: Got non boolean value for variable"
      in
      let alloc = Alloc.alloc in
      let check v = assert_ (Constraint.boolean ~label:"boolean-alloc" v ) in
      { read; store; alloc; check }
    ;;

    let spec_unchecked : (var, value) Var_spec.t =
      { spec with check = fun _ -> return () }
    ;;

    module Assert = struct
      let is_true (v : var) = assert_equal v true_

      (* Someday: Make more efficient *)
      let any vs = any vs >>= is_true

      let all vs =
        assert_all (List.map vs ~f:(fun v -> Constraint.equal v true_))
    end

    module Expr = struct
      type t =
        | Var of var
        | And of t list
        | Or of t list
        | Not of t

      let rec eval t =
        let open Let_syntax in
        match t with
        | Not t -> eval t >>| not
        | Var v -> return v
        | And ts ->
          Checked1.all (List.map ~f:eval ts) >>= all
        | Or ts ->
          Checked1.all (List.map ~f:eval ts) >>= any
      ;;

      let assert_ t = eval t >>= assert_equal true_

      let (!) v    = Var v
      let (&&) x y = And [x; y]
      let (||) x y = Or [x; y]
      let not t    = Not t
      let any xs   = Or xs
      let all xs   = And xs
    end
  end

  let unpack (v : Cvar.t) ~length
    : (Boolean.var list, 's) t
    =
    let open Let_syntax in
    let%bind res =
      exists (Var_spec.list Boolean.spec ~length) begin
        let open As_prover.Let_syntax in
        let%map x = As_prover.read_var v in
        let x = Bigint.of_field x in
        List.init length ~f:(fun i ->
          Bigint.test_bit x i)
      end
    in
    let lc =
      let ts, _ =
        List.fold_left res ~init:([], Field.one) ~f:(fun (acc, c) v ->
          ((c, v) :: acc, Field.add c c))
      in
      Cvar.linear_combination ts
    in
    let%map () = assert_r1cs ~label:"unpack" lc (Cvar.constant Field.one) v in
    res
  ;;

  let pack (vars : Boolean.var list) =
    (* TODO: Can this be <= ? *)
    assert (List.length vars < Field.size_in_bits);
    let rec go c acc = function
      | [] -> List.rev acc
      | v :: vs -> go (Field.add c c) ((c, v) :: acc) vs
    in
    Cvar.linear_combination (go Field.one [] vars)
  ;;

  module Assert = struct
    let equal_bitstrings (t1 : Boolean.var list) (t2 : Boolean.var list) =
      let chunk_size = Field.size_in_bits - 1 in
      let rec go acc t1 t2 =
        match t1, t2 with
        | [], [] -> acc
        | _, _ ->
          let (t1_a, t1_b) = List.split_n t1 chunk_size in
          let (t2_a, t2_b) = List.split_n t2 chunk_size in
          go (Constraint.equal (pack t1_a) (pack t2_a) :: acc) t1_b t2_b
      in
      assert_all ~label:"Checked.Assert.equal_bitstrings" (go [] t1 t2)
    ;;

    let non_zero (v : Cvar.t) =
      with_label "Checked.Assert.non_zero" Let_syntax.(let%map _ =  inv v in ())
    ;;

    let not_equal (x : Cvar.t) (y : Cvar.t) =
      with_label "Checked.Assert.not_equal" (non_zero (Cvar.sub x y))
    ;;

    let any (bs : Boolean.var list) =
      with_label "Checked.Assert.any" (non_zero (Cvar.sum (bs :> Cvar.t list)))
    ;;

    let exactly_one  (bs : Boolean.var list) =
      with_label "Checked.Assert.exactly_one"
        (assert_equal (Cvar.sum bs) (Cvar.constant Field.one))
    ;;
  end
end

module Data_spec = Var_spec.Data_spec

module Run = struct
  open Data_spec

  let alloc_var next_input =
    fun () ->
      let v = Backend.Var.create !next_input in
      incr next_input;
      v
  ;;

  let rec collect_input_constraints
    : type s r2 k1 k2.
      int ref
      -> ((unit, s) Checked.t, r2, k1, k2) t
      -> k1
      -> (unit, s) Checked.t
    =
    fun next_input t k ->
      match t with
      | [] -> k
      | { alloc; check; _ } :: t' ->
        let var = Var_spec.Alloc.run alloc (alloc_var next_input) in
        let r = collect_input_constraints next_input t' (k var) in
        let open Checked.Let_syntax in
        let%map () = Checked.with_state (As_prover.return ()) (check var)
        and ()     = r
        in
        ()
  ;;

  let rec r1cs_h
    : type s r2 k1 k2. int ref
      -> ((unit, s) Checked.t, r2, k1, k2) t
      -> k1
      -> R1CS_constraint_system.t
    =
    fun next_input t k ->
      let r = collect_input_constraints next_input t k in
      Checked.constraint_system ~num_inputs:(!next_input - 1) r
  ;;

  let constraint_system : ((unit, 's) Checked.t, _, 'k_var, _) t -> 'k_var -> R1CS_constraint_system.t =
    fun t k -> r1cs_h (ref 1) t k
  ;;

  let generate_keypair
    : ((unit, 's) Checked.t, _, 'k_var, _) t
      -> 'k_var
      -> Keypair.t
    =
    fun t k ->
      Backend.R1CS_constraint_system.create_keypair (constraint_system t k)

  let verify
    : Proof.t
      -> Verification_key.t
      -> ('r_var, bool, 'k_var, 'k_value) t
      -> 'k_value
    =
    fun proof vk t0 ->
      let primary_input = Field.Vector.create () in
      let store_field_elt =
        let next_input = ref 1 in
        fun x ->
          let v = Backend.Var.create !next_input in
          incr next_input;
          Field.Vector.emplace_back primary_input x;
          v
      in
      let rec go : type r_var k_var k_value.
        (r_var, bool, k_var, k_value) t -> k_value
        =
        fun t ->
          match t with
          | [] -> Proof.verify proof vk primary_input
          | { store; _ } :: t' ->
            fun value ->
              let _var =
                Var_spec.Store.run (store value) store_field_elt
              in
              go t'
      in
      go t0
  ;;

  let conv
    : type r_var r_value.
      (r_var -> Field.Vector.t -> r_value)
      -> (r_var, r_value, 'k_var, 'k_value) t
      -> 'k_var
      -> 'k_value
    =
    fun cont0 t0 k0 ->
      let primary_input = Field.Vector.create () in
      let store_field_elt =
        let next_input = ref 1 in
        fun x ->
          let v = Backend.Var.create !next_input in
          incr next_input;
          Field.Vector.emplace_back primary_input x;
          v
      in
      let rec go : type k_var k_value.
        (r_var, r_value, k_var, k_value) t -> k_var -> k_value =
        fun t k ->
          match t with
          | [] -> cont0 k primary_input
          | { store; _ } :: t' ->
            fun value ->
              let var =
                Var_spec.Store.run (store value) store_field_elt
              in
              go t' (k var)
      in
      go t0 k0
  ;;

  let prove
    : Proving_key.t
      -> ((unit, 's) Checked.t, Proof.t, 'k_var, 'k_value) t
      -> 's
      -> 'k_var
      -> 'k_value
    =
    fun key t s k ->
      conv (fun c primary ->
        Proof.create key ~primary
          ~auxiliary:(
            Checked.auxiliary_input
              ~num_inputs:(Field.Vector.length primary)
              c s primary))
        t
        k
  ;;
end

include Checked

let generate_keypair = Run.generate_keypair
let prove = Run.prove
let verify = Run.verify

end
