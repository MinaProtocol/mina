(* TODO: remove these openings *)
open Sponge
open Unsigned.Size_t

(* TODO: open Core here instead of opening it multiple times below *)

(** A gate interface, parameterized by a field. *)
module type Gate_vector_intf = sig
  open Unsigned

  type field

  type t

  val create : unit -> t

  val add : t -> field Kimchi_types.circuit_gate -> unit

  val get : t -> int -> field Kimchi_types.circuit_gate

  val digest : int -> t -> bytes

  val get_asm : int -> t -> string
end

(** A row indexing in a constraint system. *)
module Row = struct
  open Core_kernel

  (** Either a public input row, 
      or a non-public input row that starts at index 0. 
    *)
  type t = Public_input of int | After_public_input of int
  [@@deriving hash, sexp, compare]

  let to_absolute ~public_input_size = function
    | Public_input i ->
        i
    | After_public_input i ->
        (* the first i rows are public-input rows *)
        i + public_input_size
end

(* TODO: rename module Position to Permutation/Wiring? *)

(** A position represents the position of a cell in the constraint system. *)
module Position = struct
  open Core_kernel

  (** A position is a row and a column. *)
  type 'row t = { row : 'row; col : int } [@@deriving hash, sexp, compare]

  (** Generates a full row of positions that each points to itself. *)
  let create_cols (row : 'row) : _ t array =
    Array.init Constants.permutation_cols ~f:(fun i -> { row; col = i })

  (** Given a number of columns, 
      append enough column wires to get an entire row.
      The wire appended will simply point to themselves,
      so as to not take part in the permutation argument. 
    *)
  let append_cols (row : 'row) (cols : _ t array) : _ t array =
    let padding_offset = Array.length cols in
    assert (padding_offset <= Constants.permutation_cols) ;
    let padding_len = Constants.permutation_cols - padding_offset in
    let padding =
      Array.init padding_len ~f:(fun i -> { row; col = i + padding_offset })
    in
    Array.append cols padding

  (** Converts an array of [Constants.columns] to [Constants.permutation_cols]. 
    This is useful to truncate arrays of cells to the ones that only matter for the permutation argument. 
    *)
  let cols_to_perms cols = Array.slice cols 0 Constants.permutation_cols

  (** Converts a [Position.t] into the Rust-compatible type [Kimchi_types.wire]. 
    *)
  let to_rust_wire { row; col } : Kimchi_types.wire = { row; col }
end

(** A gate. *)
module Gate_spec = struct
  open Core_kernel

  (* TODO: split kind/coeffs from row/wired_to *)

  (** A gate/row/constraint consists of a type (kind), a row, the other cells its columns/cells are connected to (wired_to), and the selector polynomial associated with the gate. *)
  type ('row, 'f) t =
    { kind : (Kimchi_types.gate_type[@sexp.opaque])
    ; wired_to : 'row Position.t array
    ; coeffs : 'f array
    }
  [@@deriving sexp_of]

  (** Applies a function [f] to the [row] of [t] and all the rows of its [wired_to]. *)
  let map_rows (t : (_, _) t) ~f : (_, _) t =
    (* { wire with row = f row } *)
    let wired_to =
      Array.map
        ~f:(fun (pos : _ Position.t) -> { pos with row = f pos.row })
        t.wired_to
    in
    { t with wired_to }

  (* TODO: just send the array to Rust directly *)
  let to_rust_gate { kind; wired_to; coeffs } : _ Kimchi_types.circuit_gate =
    let typ = kind in
    let wired_to = Array.map ~f:Position.to_rust_wire wired_to in
    let wires =
      ( wired_to.(0)
      , wired_to.(1)
      , wired_to.(2)
      , wired_to.(3)
      , wired_to.(4)
      , wired_to.(5)
      , wired_to.(6) )
    in
    { typ; wires; coeffs }
end

(** The PLONK constraints. *)
module Plonk_constraint = struct
  open Core_kernel

  (** A PLONK constraint (or gate) can be [Basic], [Poseidon], [EC_add_complete], [EC_scale], [EC_endoscale], or [EC_endoscalar]. *)
  module T = struct
    type ('v, 'f) t =
      | Basic of { l : 'f * 'v; r : 'f * 'v; o : 'f * 'v; m : 'f; c : 'f }
          (** the Poseidon state is an array of states (and states are arrays of size 3). *)
      | Poseidon of { state : 'v array array }
      | EC_add_complete of
          { p1 : 'v * 'v
          ; p2 : 'v * 'v
          ; p3 : 'v * 'v
          ; inf : 'v
          ; same_x : 'v
          ; slope : 'v
          ; inf_z : 'v
          ; x21_inv : 'v
          }
      | EC_scale of { state : 'v Scale_round.t array }
      | EC_endoscale of
          { state : 'v Endoscale_round.t array; xs : 'v; ys : 'v; n_acc : 'v }
      | EC_endoscalar of { state : 'v Endoscale_scalar_round.t array }
    [@@deriving sexp]

    (** map t *)
    let map (type a b f) (t : (a, f) t) ~(f : a -> b) =
      let fp (x, y) = (f x, f y) in
      match t with
      | Basic { l; r; o; m; c } ->
          let p (x, y) = (x, f y) in
          Basic { l = p l; r = p r; o = p o; m; c }
      | Poseidon { state } ->
          Poseidon { state = Array.map ~f:(fun x -> Array.map ~f x) state }
      | EC_add_complete { p1; p2; p3; inf; same_x; slope; inf_z; x21_inv } ->
          EC_add_complete
            { p1 = fp p1
            ; p2 = fp p2
            ; p3 = fp p3
            ; inf = f inf
            ; same_x = f same_x
            ; slope = f slope
            ; inf_z = f inf_z
            ; x21_inv = f x21_inv
            }
      | EC_scale { state } ->
          EC_scale
            { state = Array.map ~f:(fun x -> Scale_round.map ~f x) state }
      | EC_endoscale { state; xs; ys; n_acc } ->
          EC_endoscale
            { state = Array.map ~f:(fun x -> Endoscale_round.map ~f x) state
            ; xs = f xs
            ; ys = f ys
            ; n_acc = f n_acc
            }
      | EC_endoscalar { state } ->
          EC_endoscalar
            { state =
                Array.map ~f:(fun x -> Endoscale_scalar_round.map ~f x) state
            }

    (** [eval (module F) get_variable gate] checks that [gate]'s polynomial is
        satisfied by the assignments given by [get_variable].
        Warning: currently only implemented for the [Basic] gate.
    *)
    let eval (type v f)
        (module F : Snarky_backendless.Field_intf.S with type t = f)
        (eval_one : v -> f) (t : (v, f) t) =
      match t with
      (* cl * vl + cr * vr + co * vo + m * vl*vr + c = 0 *)
      | Basic { l = cl, vl; r = cr, vr; o = co, vo; m; c } ->
          let vl = eval_one vl in
          let vr = eval_one vr in
          let vo = eval_one vo in
          let open F in
          let res =
            List.reduce_exn ~f:add
              [ mul cl vl; mul cr vr; mul co vo; mul m (mul vl vr); c ]
          in
          if not (equal zero res) then (
            eprintf
              !"%{sexp:t} * %{sexp:t}\n\
                + %{sexp:t} * %{sexp:t}\n\
                + %{sexp:t} * %{sexp:t}\n\
                + %{sexp:t} * %{sexp:t}\n\
                + %{sexp:t}\n\
                = %{sexp:t}%!"
              cl vl cr vr co vo m (mul vl vr) c res ;
            false )
          else true
      | _ ->
          true
  end

  include T

  (* Adds our constraint enum to the list of constraints handled by Snarky. *)
  include Snarky_backendless.Constraint.Add_kind (T)
end

module Internal_var = Core_kernel.Unique_id.Int ()

module V = struct
  open Core_kernel

  module T = struct
    (** Variables linking uses of the same data between different gates.

        Every internal variable is computable from a finite list of external
        variables and internal variables.
        Currently, in fact, every internal variable is a linear combination of
        external variables and previously generated internal variables.
    *)
    type t =
      | External of int
          (** An external variable (generated by snarky, via [exists]). *)
      | Internal of Internal_var.t
          (** An internal variable is generated to hold an intermediate value
              (e.g., in reducing linear combinations to single PLONK positions).
          *)
    [@@deriving compare, hash, sexp]
  end

  include T
  include Comparable.Make (T)
  include Hashable.Make (T)
end

(** Keeps track of a circuit (which is a list of gates)
    while it is being written.
  *)
type ('f, 'rust_gates) circuit =
  | Unfinalized_rev of (unit, 'f) Gate_spec.t list
      (** A circuit still being written. *)
  | Compiled of Core_kernel.Md5.t * 'rust_gates
      (** Once finalized, a circuit is represented as a digest 
    and a list of gates that corresponds to the circuit. 
  *)

(** The constraint system. *)
type ('f, 'rust_gates) t =
  { (* Map of cells that share the same value (enforced by to the permutation). *)
    equivalence_classes : Row.t Position.t list V.Table.t
  ; (* How to compute each internal variable (as a linear combination of other variables). *)
    internal_vars : (('f * V.t) list * 'f option) Internal_var.Table.t
  ; (* The variables that hold each witness value for each row, in reverse order. *)
    mutable rows_rev : V.t option array list
  ; (* A circuit is described by a series of gates.
       A gate is finalized once [finalize_and_get_gates] is called.
       The finalized tag contains the digest of the circuit.
    *)
    mutable gates : ('f, 'rust_gates) circuit
  ; (* The row to use the next time we add a constraint. *)
    mutable next_row : int
  ; (* The size of the public input (which fills the first rows of our constraint system. *)
    public_input_size : int Core_kernel.Set_once.t
  ; (* The number of previous recursion challenges. *)
    prev_challenges : int Core_kernel.Set_once.t
  ; (* Whatever is not public input. *)
    mutable auxiliary_input_size : int
  ; (* Queue (of size 1) of generic gate. *)
    mutable pending_generic_gate :
      (V.t option * V.t option * V.t option * 'f array) option
  ; (* V.t's corresponding to constant values. We reuse them so we don't need to
       use a fresh generic constraint each time to create a constant.
    *)
    cached_constants : ('f, V.t) Core_kernel.Hashtbl.t
        (* The [equivalence_classes] field keeps track of the positions which must be
             enforced to be equivalent due to the fact that they correspond to the same V.t value.
             I.e., positions that are different usages of the same [V.t].

             We use a union-find data structure to track equalities that a constraint system wants
             enforced *between* [V.t] values. Then, at the end, for all [V.t]s that have been unioned
             together, we combine their equivalence classes in the [equivalence_classes] table into
             a single equivalence class, so that the permutation argument enforces these desired equalities
             as well.
        *)
  ; union_finds : V.t Core_kernel.Union_find.t V.Table.t
  }

let get_public_input_size sys = sys.public_input_size

let get_rows_len sys = List.length sys.rows_rev

let get_prev_challenges sys = sys.prev_challenges

let set_prev_challenges sys challenges =
  Core_kernel.Set_once.set_exn sys.prev_challenges [%here] challenges

(* TODO: shouldn't that Make create something bounded by a signature? As we know what a back end should be? Check where this is used *)

(* TODO: glossary of terms in this file (terms, reducing, feeding) + module doc *)

(* TODO: rename Fp to F or Field *)

(** ? *)
module Make
    (Fp : Field.S)
    (* We create a type for gate vector, instead of using `Gate.t list`. If we did, we would have to convert it to a `Gate.t array` to pass it across the FFI boundary, where then it gets converted to a `Vec<Gate>`; it's more efficient to just create the `Vec<Gate>` directly. 
    *)
    (Gates : Gate_vector_intf with type field := Fp.t)
    (Params : sig
      val params : Fp.t Params.t
    end) =
struct
  open Core_kernel
  open Pickles_types

  type nonrec t = (Fp.t, Gates.t) t

  (** Converts the set of permutations (equivalence_classes) to
      a hash table that maps each position to the next one.
      For example, if one of the equivalence class is [pos1, pos3, pos7],
      the function will return a hashtable that maps pos1 to pos3,
      pos3 to pos7, and pos7 to pos1. 
    *)
  let equivalence_classes_to_hashtbl sys =
    let module Relative_position = struct
      module T = struct
        type t = Row.t Position.t [@@deriving hash, sexp, compare]
      end

      include T
      include Core_kernel.Hashable.Make (T)
    end in
    let equivalence_classes = V.Table.create () in
    Hashtbl.iteri sys.equivalence_classes ~f:(fun ~key ~data ->
        let u = Hashtbl.find_exn sys.union_finds key in
        Hashtbl.update equivalence_classes (Union_find.get u) ~f:(function
          | None ->
              Relative_position.Hash_set.of_list data
          | Some ps ->
              List.iter ~f:(Hash_set.add ps) data ;
              ps ) ) ;
    let res = Relative_position.Table.create () in
    Hashtbl.iter equivalence_classes ~f:(fun ps ->
        let rotate_left = function [] -> [] | x :: xs -> xs @ [ x ] in
        let ps = Hash_set.to_list ps in
        List.iter2_exn ps (rotate_left ps) ~f:(fun input output ->
            Hashtbl.add_exn res ~key:input ~data:output ) ) ;
    res

  (** Compute the witness, given the constraint system `sys` 
      and a function that converts the indexed secret inputs to their concrete values.
   *)
  let compute_witness (sys : t) (external_values : int -> Fp.t) :
      Fp.t array array =
    let internal_values : Fp.t Internal_var.Table.t =
      Internal_var.Table.create ()
    in
    let public_input_size = Set_once.get_exn sys.public_input_size [%here] in
    let num_rows = public_input_size + sys.next_row in
    let res =
      Array.init Constants.columns ~f:(fun _ ->
          Array.create ~len:num_rows Fp.zero )
    in
    (* Public input *)
    for i = 0 to public_input_size - 1 do
      res.(0).(i) <- external_values (i + 1)
    done ;
    let find t k =
      match Hashtbl.find t k with
      | None ->
          failwithf !"Could not find %{sexp:Internal_var.t}\n%!" k ()
      | Some x ->
          x
    in
    (* Compute an internal variable associated value. *)
    let compute ((lc, c) : (Fp.t * V.t) list * Fp.t option) =
      List.fold lc ~init:(Option.value c ~default:Fp.zero) ~f:(fun acc (s, x) ->
          let x =
            match x with
            | External x ->
                external_values x
            | Internal x ->
                find internal_values x
          in
          Fp.(acc + (s * x)) )
    in
    (* Update the witness table with the value of the variables from each row. *)
    List.iteri (List.rev sys.rows_rev) ~f:(fun i_after_input cols ->
        let row_idx = i_after_input + public_input_size in
        Array.iteri cols ~f:(fun col_idx var ->
            match var with
            | None ->
                ()
            | Some (External var) ->
                res.(col_idx).(row_idx) <- external_values var
            | Some (Internal var) ->
                let lc = find sys.internal_vars var in
                let value = compute lc in
                res.(col_idx).(row_idx) <- value ;
                Hashtbl.set internal_values ~key:var ~data:value ) ) ;
    (* Return the witness. *)
    res

  let union_find sys v =
    Hashtbl.find_or_add sys.union_finds v ~default:(fun () ->
        Union_find.create v )

  (** Creates an internal variable and assigns it the value lc and constant. *)
  let create_internal ?constant sys lc : V.t =
    let v = Internal_var.create () in
    ignore (union_find sys (Internal v) : _ Union_find.t) ;
    Hashtbl.add_exn sys.internal_vars ~key:v ~data:(lc, constant) ;
    V.Internal v

  (* Initializes a constraint system. *)
  let create () : t =
    { public_input_size = Set_once.create ()
    ; prev_challenges = Set_once.create ()
    ; internal_vars = Internal_var.Table.create ()
    ; gates = Unfinalized_rev [] (* Gates.create () *)
    ; rows_rev = []
    ; next_row = 0
    ; equivalence_classes = V.Table.create ()
    ; auxiliary_input_size = 0
    ; pending_generic_gate = None
    ; cached_constants = Hashtbl.create (module Fp)
    ; union_finds = V.Table.create ()
    }

  (* TODO *)
  let to_json _ = `List []

  (** Returns the number of auxiliary inputs. *)
  let get_auxiliary_input_size t = t.auxiliary_input_size

  (** Returns the number of public inputs. *)
  let get_primary_input_size t = Set_once.get_exn t.public_input_size [%here]

  (** Returns the number of previous challenges. *)
  let get_prev_challenges t = Set_once.get_exn t.prev_challenges [%here]

  (* Non-public part of the witness. *)
  let set_auxiliary_input_size t x = t.auxiliary_input_size <- x

  (** Sets the number of public-input. It must and can only be called once. *)
  let set_primary_input_size (sys : t) num_pub_inputs =
    Set_once.set_exn sys.public_input_size [%here] num_pub_inputs

  (** Sets the number of previous challenges. It must and can only be called once. *)
  let set_prev_challenges (sys : t) num_prev_challenges =
    Set_once.set_exn sys.prev_challenges [%here] num_prev_challenges

  let get_public_input_size (sys : t) = get_public_input_size sys

  let get_rows_len (sys : t) = get_rows_len sys

  (** Adds {row; col} to the system's wiring under a specific key.
      A key is an external or internal variable.
      The row must be given relative to the start of the circuit 
      (so at the start of the public-input rows). *)
  let wire' sys key row (col : int) =
    ignore (union_find sys key : V.t Union_find.t) ;
    V.Table.add_multi sys.equivalence_classes ~key ~data:{ row; col }

  (* TODO: rename to wire_abs and wire_rel? or wire_public and wire_after_public? or force a single use function that takes a Row.t? *)

  (** Same as wire', except that the row must be given relatively to the end of the public-input rows. *)
  let wire sys key row col = wire' sys key (Row.After_public_input row) col

  (** Adds a row/gate/constraint to a constraint system `sys`. *)
  let add_row sys (vars : V.t option array) kind coeffs =
    match sys.gates with
    | Compiled _ ->
        failwith "add_row called on finalized constraint system"
    | Unfinalized_rev gates ->
        (* As we're adding a row, we're adding new cells.
           If these cells (the first 7) contain variables,
           make sure that they are wired
        *)
        let num_vars = min Constants.permutation_cols (Array.length vars) in
        let vars_for_perm = Array.slice vars 0 num_vars in
        Array.iteri vars_for_perm ~f:(fun col x ->
            Option.iter x ~f:(fun x -> wire sys x sys.next_row col) ) ;
        (* Add to gates. *)
        let open Position in
        sys.gates <- Unfinalized_rev ({ kind; wired_to = [||]; coeffs } :: gates) ;
        (* Increment row. *)
        sys.next_row <- sys.next_row + 1 ;
        (* Add to row. *)
        sys.rows_rev <- vars :: sys.rows_rev

  (** Adds zero-knowledgeness to the gates/rows, 
      and convert into Rust type [Gates.t].
      This can only be called once.
    *)
  let rec finalize_and_get_gates sys =
    match sys with
    | { gates = Compiled (_, gates); _ } ->
        gates
    | { pending_generic_gate = Some (l, r, o, coeffs); _ } ->
        (* Finalize any pending generic constraint first. *)
        add_row sys [| l; r; o |] Generic coeffs ;
        sys.pending_generic_gate <- None ;
        finalize_and_get_gates sys
    | { gates = Unfinalized_rev gates_rev; _ } ->
        let rust_gates = Gates.create () in

        (* Create rows for public input. *)
        let public_input_size =
          Set_once.get_exn sys.public_input_size [%here]
        in
        let pub_selectors = [| Fp.one; Fp.zero; Fp.zero; Fp.zero; Fp.zero |] in
        let pub_input_gate_specs_rev = ref [] in
        for row = 0 to public_input_size - 1 do
          let public_var = V.External (row + 1) in
          wire' sys public_var (Row.Public_input row) 0 ;
          pub_input_gate_specs_rev :=
            { Gate_spec.kind = Generic
            ; wired_to = [||]
            ; coeffs = pub_selectors
            }
            :: !pub_input_gate_specs_rev
        done ;

        (* Construct permutation hashmap. *)
        let pos_map = equivalence_classes_to_hashtbl sys in
        let permutation (pos : Row.t Position.t) : Row.t Position.t =
          Option.value (Hashtbl.find pos_map pos) ~default:pos
        in

        let update_gate_with_permutation_info (row : Row.t)
            (gate : (unit, _) Gate_spec.t) : (Row.t, _) Gate_spec.t =
          { gate with
            wired_to =
              Array.init Constants.permutation_cols ~f:(fun col ->
                  permutation { row; col } )
          }
        in

        (* Process public gates. *)
        let public_gates = List.rev !pub_input_gate_specs_rev in
        let public_gates =
          List.mapi public_gates ~f:(fun absolute_row gate ->
              update_gate_with_permutation_info (Row.Public_input absolute_row)
                gate )
        in

        (* construct all the other gates (except zero-knowledge rows) *)
        let gates = List.rev gates_rev in
        let gates =
          List.mapi gates ~f:(fun relative_row gate ->
              update_gate_with_permutation_info
                (Row.After_public_input relative_row) gate )
        in

        (* concatenate and convert to absolute rows *)
        let to_absolute_row =
          Gate_spec.map_rows ~f:(Row.to_absolute ~public_input_size)
        in

        (* convert all the gates into our Gates.t Rust vector type *)
        let add_gates gates =
          List.iter gates ~f:(fun g ->
              let g = to_absolute_row g in
              Gates.add rust_gates (Gate_spec.to_rust_gate g) )
        in
        add_gates public_gates ;
        add_gates gates ;

        (* compute the circuit's digest *)
        let digest = Gates.digest public_input_size rust_gates in
        let md5_digest = Md5.digest_bytes digest in

        (* drop the gates, we don't need them anymore *)
        sys.gates <- Compiled (md5_digest, rust_gates) ;

        (* return the gates *)
        rust_gates

  (** Calls [finalize_and_get_gates] and ignores the result. *)
  let finalize t = ignore (finalize_and_get_gates t : Gates.t)

  let get_asm (sys : t) : string =
    let gates = finalize_and_get_gates sys in
    let public_input_size = Set_once.get_exn sys.public_input_size [%here] in
    Gates.get_asm public_input_size gates

  (* Returns a hash of the circuit. *)
  let rec digest (sys : t) =
    match sys.gates with
    | Unfinalized_rev _ ->
        finalize sys ; digest sys
    | Compiled (digest, _) ->
        digest

  (** Regroup terms that share the same variable. 
      For example, (3, i2) ; (2, i2) can be simplified to (5, i2).
      It assumes that the list of given terms is sorted, 
      and that i0 is the smallest one.
      For example, `i0 = 1` and `terms = [(_, 2); (_, 2); (_; 4); ...]`

      Returns `(last_scalar, last_variable, terms, terms_length)`
      where terms does not contain the last scalar and last variable observed.
  *)
  let accumulate_terms terms =
    List.fold terms ~init:Int.Map.empty ~f:(fun acc (x, i) ->
        Map.change acc i ~f:(fun y ->
            let res = match y with None -> x | Some y -> Fp.add x y in
            if Fp.(equal zero res) then None else Some res ) )

  (** Converts a [Cvar.t] to a `(terms, terms_length, has_constant)`.
      if `has_constant` is set, then terms start with a constant term in the form of (c, 0).
    *)
  let canonicalize x =
    let c, terms =
      Fp.(
        Snarky_backendless.Cvar.to_constant_and_terms ~add ~mul ~zero:(of_int 0)
          ~equal ~one:(of_int 1))
        x
    in
    (* Note: [(c, 0)] represents the field element [c] multiplied by the 0th
       variable, which is held constant as [Field.one].
    *)
    let terms = match c with None -> terms | Some c -> (c, 0) :: terms in
    let has_constant_term = Option.is_some c in
    let terms = accumulate_terms terms in
    let terms_list =
      Map.fold_right ~init:[] terms ~f:(fun ~key ~data acc ->
          (data, key) :: acc )
    in
    Some (terms_list, Map.length terms, has_constant_term)

  (** Adds a generic constraint to the constraint system. 
      As there are two generic gates per row, we queue
      every other generic gate.
      *)
  let add_generic_constraint ?l ?r ?o coeffs sys : unit =
    match sys.pending_generic_gate with
    (* if the queue of generic gate is empty, queue this *)
    | None ->
        sys.pending_generic_gate <- Some (l, r, o, coeffs)
    (* otherwise empty the queue and create the row  *)
    | Some (l2, r2, o2, coeffs2) ->
        let coeffs = Array.append coeffs coeffs2 in
        add_row sys [| l; r; o; l2; r2; o2 |] Generic coeffs ;
        sys.pending_generic_gate <- None

  (** Converts a number of scaled additions \sum s_i * x_i 
      to as many constraints as needed, 
      creating temporary variables for each new row/constraint,
      and returning the output variable.

      For example, [(s1, x1), (s2, x2)] is transformed into:
      - internal_var_1 = s1 * x1 + s2 * x2
      - return (1, internal_var_1)

      and [(s1, x1), (s2, x2), (s3, x3)] is transformed into:
      - internal_var_1 = s1 * x1 + s2 * x2
      - internal_var_2 = 1 * internal_var_1 + s3 * x3
      - return (1, internal_var_2)
      
      It assumes that the list of terms is not empty. *)
  let completely_reduce sys (terms : (Fp.t * int) list) =
    (* just adding constrained variables without values *)
    let rec go = function
      | [] ->
          assert false
      | [ (s, x) ] ->
          (s, V.External x)
      | (ls, lx) :: t ->
          let lx = V.External lx in
          (* TODO: this should be rewritten to be tail-optimized *)
          let rs, rx = go t in
          let s1x1_plus_s2x2 = create_internal sys [ (ls, lx); (rs, rx) ] in
          add_generic_constraint ~l:lx ~r:rx ~o:s1x1_plus_s2x2
            [| ls; rs; Fp.(negate one); Fp.zero; Fp.zero |]
            sys ;
          (Fp.one, s1x1_plus_s2x2)
    in
    go terms

  (** Converts a linear combination of variables into a set of constraints.
      It returns the output variable as (1, `Var res), 
      unless the output is a constant, in which case it returns (c, `Constant). 
    *)
  let reduce_lincom sys (x : Fp.t Snarky_backendless.Cvar.t) =
    let constant, terms =
      Fp.(
        Snarky_backendless.Cvar.to_constant_and_terms ~add ~mul ~zero:(of_int 0)
          ~equal ~one:(of_int 1))
        x
    in
    let terms = accumulate_terms terms in
    let terms_list =
      Map.fold_right ~init:[] terms ~f:(fun ~key ~data acc ->
          (data, key) :: acc )
    in
    match (constant, Map.is_empty terms) with
    | Some c, true ->
        (c, `Constant)
    | None, true ->
        (Fp.zero, `Constant)
    | _ -> (
        match terms_list with
        | [] ->
            assert false
        | [ (ls, lx) ] -> (
            match constant with
            | None ->
                (ls, `Var (V.External lx))
            | Some c ->
                (* res = ls * lx + c *)
                let res =
                  create_internal ~constant:c sys [ (ls, External lx) ]
                in
                add_generic_constraint ~l:(External lx) ~o:res
                  [| ls; Fp.zero; Fp.(negate one); Fp.zero; c |]
                  (* Could be here *)
                  sys ;
                (Fp.one, `Var res) )
        | (ls, lx) :: tl ->
            (* reduce the terms, then add the constant *)
            let rs, rx = completely_reduce sys tl in
            let res =
              create_internal ?constant sys [ (ls, External lx); (rs, rx) ]
            in
            (* res = ls * lx + rs * rx + c *)
            add_generic_constraint ~l:(External lx) ~r:rx ~o:res
              [| ls
               ; rs
               ; Fp.(negate one)
               ; Fp.zero
               ; (match constant with Some x -> x | None -> Fp.zero)
              |]
              (* Could be here *)
              sys ;
            (Fp.one, `Var res) )

  (** Adds a constraint to the constraint system. *)
  let add_constraint ?label:_ sys
      (constr :
        ( Fp.t Snarky_backendless.Cvar.t
        , Fp.t )
        Snarky_backendless.Constraint.basic ) =
    let red = reduce_lincom sys in
    (* reduce any [Cvar.t] to a single internal variable *)
    let reduce_to_v (x : Fp.t Snarky_backendless.Cvar.t) : V.t =
      match red x with
      | s, `Var x ->
          if Fp.equal s Fp.one then x
          else
            let sx = create_internal sys [ (s, x) ] in
            (* s * x - sx = 0 *)
            add_generic_constraint ~l:x ~o:sx
              [| s; Fp.zero; Fp.(negate one); Fp.zero; Fp.zero |]
              sys ;
            sx
      | s, `Constant -> (
          match Hashtbl.find sys.cached_constants s with
          | Some x ->
              x
          | None ->
              let x = create_internal sys ~constant:s [] in
              add_generic_constraint ~l:x
                [| Fp.one; Fp.zero; Fp.zero; Fp.zero; Fp.negate s |]
                sys ;
              Hashtbl.set sys.cached_constants ~key:s ~data:x ;
              x )
    in
    match constr with
    | Snarky_backendless.Constraint.Square (v1, v2) -> (
        match (red v1, red v2) with
        | (sl, `Var xl), (so, `Var xo) ->
            (* (sl * xl)^2 = so * xo
               sl^2 * xl * xl - so * xo = 0
            *)
            add_generic_constraint ~l:xl ~r:xl ~o:xo
              [| Fp.zero; Fp.zero; Fp.negate so; Fp.(sl * sl); Fp.zero |]
              sys
        | (sl, `Var xl), (so, `Constant) ->
            (* TODO: it's hard to read the array of selector values, name them! *)
            add_generic_constraint ~l:xl ~r:xl
              [| Fp.zero; Fp.zero; Fp.zero; Fp.(sl * sl); Fp.negate so |]
              sys
        | (sl, `Constant), (so, `Var xo) ->
            (* sl^2 = so * xo *)
            add_generic_constraint ~o:xo
              [| Fp.zero; Fp.zero; so; Fp.zero; Fp.negate (Fp.square sl) |]
              sys
        | (sl, `Constant), (so, `Constant) ->
            assert (Fp.(equal (square sl) so)) )
    | Snarky_backendless.Constraint.R1CS (v1, v2, v3) -> (
        match (red v1, red v2, red v3) with
        | (s1, `Var x1), (s2, `Var x2), (s3, `Var x3) ->
            (* s1 x1 * s2 x2 = s3 x3
               - s1 s2 (x1 x2) + s3 x3 = 0
            *)
            add_generic_constraint ~l:x1 ~r:x2 ~o:x3
              [| Fp.zero; Fp.zero; s3; Fp.(negate s1 * s2); Fp.zero |]
              sys
        | (s1, `Var x1), (s2, `Var x2), (s3, `Constant) ->
            add_generic_constraint ~l:x1 ~r:x2
              [| Fp.zero; Fp.zero; Fp.zero; Fp.(s1 * s2); Fp.negate s3 |]
              sys
        | (s1, `Var x1), (s2, `Constant), (s3, `Var x3) ->
            (* s1 x1 * s2 = s3 x3
            *)
            add_generic_constraint ~l:x1 ~o:x3
              [| Fp.(s1 * s2); Fp.zero; Fp.negate s3; Fp.zero; Fp.zero |]
              sys
        | (s1, `Constant), (s2, `Var x2), (s3, `Var x3) ->
            add_generic_constraint ~r:x2 ~o:x3
              [| Fp.zero; Fp.(s1 * s2); Fp.negate s3; Fp.zero; Fp.zero |]
              sys
        | (s1, `Var x1), (s2, `Constant), (s3, `Constant) ->
            add_generic_constraint ~l:x1
              [| Fp.(s1 * s2); Fp.zero; Fp.zero; Fp.zero; Fp.negate s3 |]
              sys
        | (s1, `Constant), (s2, `Var x2), (s3, `Constant) ->
            add_generic_constraint ~r:x2
              [| Fp.zero; Fp.(s1 * s2); Fp.zero; Fp.zero; Fp.negate s3 |]
              sys
        | (s1, `Constant), (s2, `Constant), (s3, `Var x3) ->
            add_generic_constraint ~o:x3
              [| Fp.zero; Fp.zero; s3; Fp.zero; Fp.(negate s1 * s2) |]
              sys
        | (s1, `Constant), (s2, `Constant), (s3, `Constant) ->
            assert (Fp.(equal s3 Fp.(s1 * s2))) )
    | Snarky_backendless.Constraint.Boolean v -> (
        let s, x = red v in
        match x with
        | `Var x ->
            (* -x + x * x = 0  *)
            add_generic_constraint ~l:x ~r:x
              [| Fp.(negate one); Fp.zero; Fp.zero; Fp.one; Fp.zero |]
              sys
        | `Constant ->
            assert (Fp.(equal s (s * s))) )
    | Snarky_backendless.Constraint.Equal (v1, v2) -> (
        let (s1, x1), (s2, x2) = (red v1, red v2) in
        match (x1, x2) with
        | `Var x1, `Var x2 ->
            if Fp.equal s1 s2 then (
              if not (Fp.equal s1 Fp.zero) then
                Union_find.union (union_find sys x1) (union_find sys x2) )
            else if (* s1 x1 - s2 x2 = 0
          *)
                    not (Fp.equal s1 s2) then
              add_generic_constraint ~l:x1 ~r:x2
                [| s1; Fp.(negate s2); Fp.zero; Fp.zero; Fp.zero |]
                sys
            else
              add_generic_constraint ~l:x1 ~r:x2
                [| s1; Fp.(negate s2); Fp.zero; Fp.zero; Fp.zero |]
                sys
        | `Var x1, `Constant -> (
            (* s1 * x1 = s2
               x1 = s2 / s1
            *)
            let ratio = Fp.(s2 / s1) in
            match Hashtbl.find sys.cached_constants ratio with
            | Some x2 ->
                Union_find.union (union_find sys x1) (union_find sys x2)
            | None ->
                add_generic_constraint ~l:x1
                  [| s1; Fp.zero; Fp.zero; Fp.zero; Fp.negate s2 |]
                  sys ;
                Hashtbl.set sys.cached_constants ~key:ratio ~data:x1 )
        | `Constant, `Var x2 -> (
            (* s1 = s2 * x2
               x2 = s1 / s2
            *)
            let ratio = Fp.(s1 / s2) in
            match Hashtbl.find sys.cached_constants ratio with
            | Some x1 ->
                Union_find.union (union_find sys x1) (union_find sys x2)
            | None ->
                add_generic_constraint ~r:x2
                  [| Fp.zero; s2; Fp.zero; Fp.zero; Fp.negate s1 |]
                  sys ;
                Hashtbl.set sys.cached_constants ~key:ratio ~data:x2 )
        | `Constant, `Constant ->
            assert (Fp.(equal s1 s2)) )
    | Plonk_constraint.T (Basic { l; r; o; m; c }) ->
        (* 0
           = l.s * l.x
           + r.s * r.x
           + o.s * o.x
           + m * (l.x * r.x)
           + c
           =
             l.s * l.s' * l.x'
           + r.s * r.s' * r.x'
           + o.s * o.s' * o.x'
           + m * (l.s' * l.x' * r.s' * r.x')
           + c
           =
             (l.s * l.s') * l.x'
           + (r.s * r.s') * r.x'
           + (o.s * o.s') * o.x'
           + (m * l.s' * r.s') * l.x' r.x'
           + c
        *)
        (* TODO: This is sub-optimal *)
        let c = ref c in
        let red_pr (s, x) =
          match red x with
          | s', `Constant ->
              c := Fp.add !c Fp.(s * s') ;
              (* No need to have a real term. *)
              (s', None)
          | s', `Var x ->
              (s', Some (Fp.(s * s'), x))
        in
        (* l.s * l.x
           + r.s * r.x
           + o.s * o.x
           + m * (l.x * r.x)
           + c
           =
             l.s * l.s' * l.x'
           + r.s * r.x
           + o.s * o.x
           + m * (l.x * r.x)
           + c
           =
        *)
        let l_s', l = red_pr l in
        let r_s', r = red_pr r in
        let _, o = red_pr o in
        let var = Option.map ~f:snd in
        let coeff = Option.value_map ~default:Fp.zero ~f:fst in
        let m =
          match (l, r) with
          | Some _, Some _ ->
              Fp.(l_s' * r_s' * m)
          | _ ->
              (* TODO: Figure this out later. *)
              failwith "Must use non-constant cvar in plonk constraints"
        in
        add_generic_constraint ?l:(var l) ?r:(var r) ?o:(var o)
          [| coeff l; coeff r; coeff o; m; !c |]
          sys
    (* | w0 | w1 | w2 | w3 | w4 | w5
       state = [ x , x  , x ], [ y, y, y ], ... ]
                 i=0, perm^   i=1, perm^
    *)
    | Plonk_constraint.T (Poseidon { state }) ->
        (* reduce the state *)
        let reduce_state sys (s : Fp.t Snarky_backendless.Cvar.t array array) :
            V.t array array =
          Array.map ~f:(Array.map ~f:reduce_to_v) s
        in
        let state = reduce_state sys state in
        (* add_round_state adds a row that contains 5 rounds of permutation *)
        let add_round_state ~round (s1, s2, s3, s4, s5) =
          let vars =
            [| Some s1.(0)
             ; Some s1.(1)
             ; Some s1.(2)
             ; Some s5.(0) (* the last state is in 2nd position *)
             ; Some s5.(1)
             ; Some s5.(2)
             ; Some s2.(0)
             ; Some s2.(1)
             ; Some s2.(2)
             ; Some s3.(0)
             ; Some s3.(1)
             ; Some s3.(2)
             ; Some s4.(0)
             ; Some s4.(1)
             ; Some s4.(2)
            |]
          in
          let coeffs =
            [| Params.params.round_constants.(round).(0)
             ; Params.params.round_constants.(round).(1)
             ; Params.params.round_constants.(round).(2)
             ; Params.params.round_constants.(round + 1).(0)
             ; Params.params.round_constants.(round + 1).(1)
             ; Params.params.round_constants.(round + 1).(2)
             ; Params.params.round_constants.(round + 2).(0)
             ; Params.params.round_constants.(round + 2).(1)
             ; Params.params.round_constants.(round + 2).(2)
             ; Params.params.round_constants.(round + 3).(0)
             ; Params.params.round_constants.(round + 3).(1)
             ; Params.params.round_constants.(round + 3).(2)
             ; Params.params.round_constants.(round + 4).(0)
             ; Params.params.round_constants.(round + 4).(1)
             ; Params.params.round_constants.(round + 4).(2)
            |]
          in
          add_row sys vars Poseidon coeffs
        in
        (* add_last_row adds the last row containing the output *)
        let add_last_row state =
          let vars =
            [| Some state.(0)
             ; Some state.(1)
             ; Some state.(2)
             ; None
             ; None
             ; None
             ; None
             ; None
             ; None
             ; None
             ; None
             ; None
             ; None
             ; None
            |]
          in
          add_row sys vars Zero [||]
        in
        (* go through the states row by row (a row contains 5 states) *)
        let rec process_5_states_at_a_time ~round = function
          | [ s1; s2; s3; s4; s5; last ] ->
              add_round_state ~round (s1, s2, s3, s4, s5) ;
              add_last_row last
          | s1 :: s2 :: s3 :: s4 :: s5 :: tl ->
              add_round_state ~round (s1, s2, s3, s4, s5) ;
              process_5_states_at_a_time ~round:(round + 5) tl
          | _ ->
              failwith "incorrect number of states given"
        in
        process_5_states_at_a_time ~round:0 (Array.to_list state)
    | Plonk_constraint.T
        (EC_add_complete { p1; p2; p3; inf; same_x; slope; inf_z; x21_inv }) ->
        let reduce_curve_point (x, y) = (reduce_to_v x, reduce_to_v y) in

        (*
        //! 0   1   2   3   4   5   6   7      8   9      10      11   12   13   14
        //! x1  y1  x2  y2  x3  y3  inf same_x s   inf_z  x21_inv

        *)
        let x1, y1 = reduce_curve_point p1 in
        let x2, y2 = reduce_curve_point p2 in
        let x3, y3 = reduce_curve_point p3 in
        let vars =
          [| Some x1
           ; Some y1
           ; Some x2
           ; Some y2
           ; Some x3
           ; Some y3
           ; Some (reduce_to_v inf)
           ; Some (reduce_to_v same_x)
           ; Some (reduce_to_v slope)
           ; Some (reduce_to_v inf_z)
           ; Some (reduce_to_v x21_inv)
           ; None
           ; None
           ; None
           ; None
          |]
        in
        add_row sys vars CompleteAdd [||]
    | Plonk_constraint.T (EC_scale { state }) ->
        let i = ref 0 in
        (*
 0   1   2   3   4   5   6   7   8   9   10  11  12  13  14
 xT  yT  x0  y0  n   n'      x1  y1  x2  y2  x3  y3  x4  y4
 x5  y5  b0  b1  b2  b3  b4  s0  s1  s2  s3  s4
        *)
        let add_ecscale_round
            Scale_round.{ accs; bits; ss; base = xt, yt; n_prev; n_next } =
          let curr_row =
            [| Some xt
             ; Some yt
             ; Some (fst accs.(0))
             ; Some (snd accs.(0))
             ; Some n_prev
             ; Some n_next
             ; None
             ; Some (fst accs.(1))
             ; Some (snd accs.(1))
             ; Some (fst accs.(2))
             ; Some (snd accs.(2))
             ; Some (fst accs.(3))
             ; Some (snd accs.(3))
             ; Some (fst accs.(4))
             ; Some (snd accs.(4))
            |]
          in
          let next_row =
            [| Some (fst accs.(5))
             ; Some (snd accs.(5))
             ; Some bits.(0)
             ; Some bits.(1)
             ; Some bits.(2)
             ; Some bits.(3)
             ; Some bits.(4)
             ; Some ss.(0)
             ; Some ss.(1)
             ; Some ss.(2)
             ; Some ss.(3)
             ; Some ss.(4)
             ; None
             ; None
             ; None
            |]
          in
          add_row sys curr_row VarBaseMul [||] ;
          add_row sys next_row Zero [||]
        in

        Array.iter
          ~f:(fun round -> add_ecscale_round round ; incr i)
          (Array.map state ~f:(Scale_round.map ~f:reduce_to_v)) ;
        ()
    | Plonk_constraint.T (EC_endoscale { state; xs; ys; n_acc }) ->
        (* Reduce state. *)
        let state = Array.map state ~f:(Endoscale_round.map ~f:reduce_to_v) in
        (* Add round function. *)
        let add_endoscale_round (round : V.t Endoscale_round.t) =
          let row =
            [| Some round.xt
             ; Some round.yt
             ; None
             ; None
             ; Some round.xp
             ; Some round.yp
             ; Some round.n_acc
             ; Some round.xr
             ; Some round.yr
             ; Some round.s1
             ; Some round.s3
             ; Some round.b1
             ; Some round.b2
             ; Some round.b3
             ; Some round.b4
            |]
          in
          add_row sys row Kimchi_types.EndoMul [||]
        in
        Array.iter state ~f:add_endoscale_round ;
        (* Last row. *)
        let vars =
          [| None
           ; None
           ; None
           ; None
           ; Some (reduce_to_v xs)
           ; Some (reduce_to_v ys)
           ; Some (reduce_to_v n_acc)
           ; None
           ; None
           ; None
           ; None
           ; None
           ; None
           ; None
          |]
        in
        add_row sys vars Zero [||]
    | Plonk_constraint.T
        (EC_endoscalar { state : 'v Endoscale_scalar_round.t array }) ->
        (* Add round function. *)
        let add_endoscale_scalar_round (round : V.t Endoscale_scalar_round.t) =
          let row =
            [| Some round.n0
             ; Some round.n8
             ; Some round.a0
             ; Some round.b0
             ; Some round.a8
             ; Some round.b8
             ; Some round.x0
             ; Some round.x1
             ; Some round.x2
             ; Some round.x3
             ; Some round.x4
             ; Some round.x5
             ; Some round.x6
             ; Some round.x7
             ; None
            |]
          in
          add_row sys row Kimchi_types.EndoMulScalar [||]
        in
        Array.iter state
          ~f:
            (Fn.compose add_endoscale_scalar_round
               (Endoscale_scalar_round.map ~f:reduce_to_v) )
    | constr ->
        failwithf "Unhandled constraint %s"
          Obj.(Extension_constructor.name (Extension_constructor.of_val constr))
          ()
end
