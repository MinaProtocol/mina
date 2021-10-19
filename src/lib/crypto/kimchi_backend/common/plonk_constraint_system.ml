(* TODO: remove these openings *)
open Sponge
open Unsigned.Size_t

(* TODO: open Core here instead of opening it multiple times below *)

(** Important constants in the protocol (TODO: move to its own module file?) *)
module Constants = struct
  (** number of witness *)
  let columns = 15

  (** number of columns that take part in the permutation *)
  let permutation_cols = 7

  (* TODO: zk_rows is specified on the Rust side now, so I don't think we need this here for the permutation AT LEAST. This should be specified on the Rust side for other polynomials like the wires *)

  (* TODO: is this 3 or 2? *)

  (** number of rows used to add zero-knowledge to the witness polynomials *)
  let zk_rows = 2
end

(** a gate interface, parameterized by a field *)
module type Gate_vector_intf = sig
  open Unsigned

  type field

  type t

  val create : unit -> t

  val add : t -> field Kimchi.Protocol.circuit_gate -> unit

  val get : t -> int -> field Kimchi.Protocol.circuit_gate
end

(** A row indexing in a constraint system *)
module Row = struct
  open Core_kernel

  (** Either a public input row, or a non-public input row that starts at index 0 *)
  type t = Public_input of int | After_public_input of int
  [@@deriving hash, sexp, compare]

  let to_absolute ~public_input_size = function
    | Public_input i ->
        i
    | After_public_input i ->
        (* the first i rows are public-input rows *)
        i + public_input_size
end

(* TODO: rename module Position to Permutation? *)

(** A position represents the position of a cell in the constraint system *)
module Position = struct
  open Core_kernel

  (** A position is a row and a column *)
  type 'row t = { row : 'row; col : int } [@@deriving hash, sexp, compare]

  (** Generates a full row of positions that each points to itself *)
  let create_cols (row : 'row) : _ t array =
    Array.init Constants.permutation_cols (fun i -> { row; col = i })

  (** Given a number of columns, 
      append enough column wires to get an entire row.
      The wire appended will simply point to themselves,
      as to not take part in the permutation argument. *)
  let append_cols (row : 'row) (cols : _ t array) : _ t array =
    let padding_offset = Array.length cols in
    assert (padding_offset <= Constants.permutation_cols) ;
    let padding_len = Constants.permutation_cols - padding_offset in
    let padding =
      Array.init padding_len (fun i -> { row; col = i + padding_offset })
    in
    Array.append cols padding

  (** converts an array of [Constants.columns] to [Constants.permutation_cols]. 
    This is useful to truncate arrays of cells to the ones that only matter for the permutation argument. *)
  let cols_to_perms cols = Array.slice cols 0 Constants.permutation_cols

  (** converts a [Position.t] into the Rust-compatible type [Kimchi.Protocol.wire] *)
  let to_rust_wire { row; col } : Kimchi.Protocol.wire = { row; col }
end

(** A gate *)
module Gate_spec = struct
  (** A gate/row/constraint consists of a type (kind), a row, the other cells its columns/cells are connected to (wired_to), and the selector polynomial associated with the gate *)
  type ('row, 'f) t =
    { kind : Kimchi.Protocol.gate_type
    ; row : 'row
    ; wired_to : 'row Position.t array
    ; coeffs : 'f array
          (* TODO: shouldn't the coeffs live in the gate type enum? *)
    }

  (** applies a function [f] to the [row] of [t] and all the rows of its [wired_to] *)
  let map_rows (t : (_, _) t) ~f : (_, _) t =
    (* { wire with row = f row } *)
    let wired_to =
      Array.map
        (fun (pos : _ Position.t) -> { pos with row = f pos.row })
        t.wired_to
    in
    { t with row = f t.row; wired_to }

  let to_rust_gate { kind; row; wired_to; coeffs } :
      _ Kimchi.Protocol.circuit_gate =
    let typ = kind in
    let c = coeffs in
    let wired_to = Array.map Position.to_rust_wire wired_to in
    let wires =
      ( wired_to.(0)
      , wired_to.(1)
      , wired_to.(2)
      , wired_to.(3)
      , wired_to.(4)
      , wired_to.(5)
      , wired_to.(6)
      , wired_to.(7)
      , wired_to.(8)
      , wired_to.(9)
      , wired_to.(10)
      , wired_to.(11)
      , wired_to.(12)
      , wired_to.(13)
      , wired_to.(14) )
    in
    { typ; row; wires; c }
end

(** Represents the state of a hash function *)
module Hash_state = struct
  open Core_kernel
  module H = Digestif.SHA256

  type t = H.ctx

  (* TODO: why `md5(SHA-256(x))` instead of truncating? *)
  let digest t = Md5.digest_string H.(to_raw_string (get t))

  (* TODO: it's weird to have a function that you don't know how to call here, this probably should be wrapped with a safer interface (I'm assuming it's the initial state) *)
  let empty = H.feed_string H.empty "plonk_constraint_system_v3"
end

(** The PLONK constraints *)
module Plonk_constraint = struct
  open Core_kernel

  (** A PLONK constraint (or gate) can be [Basic], [Poseidon], [EC_add], [EC_scale] or [EC_endoscale] *)
  module T = struct
    type ('v, 'f) t =
      | Basic of { l : 'f * 'v; r : 'f * 'v; o : 'f * 'v; m : 'f; c : 'f }
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
      | EC_endoscale of { state : 'v Endoscale_round.t array } (* acc : 'v * 'v; n_acc : 'v ? *)
    [@@deriving sexp]

    (** ? *)
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
      | EC_endoscale { state } ->
          EC_endoscale
            { state = Array.map ~f:(fun x -> Endoscale_round.map ~f x) state }

    (* TODO: this seems to be a "double check" type of function? It just checks that the basic gate is equal to 0? what is eval_one? what is v and f? *)
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
            Core.eprintf
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
          (* TODO: this fails open for other gates than basic? *)
          true

    (* TODO *)
  end

  include T

  (* adds our constraint enum to the list of constraints handled by Snarky *)
  include Snarky_backendless.Constraint.Add_kind (T)
end

(* TODO: what is this? a counter? *)
module Internal_var = Core_kernel.Unique_id.Int ()

(** A hash table based on a type that represents external and internal variables. )*)
module V = struct
  open Core_kernel

  (*
   An external variable is one generated by snarky (via exists).

   An internal variable is one that we generate as an intermediate variable (e.g., in
   reducing linear combinations to single PLONK positions).

   Every internal variable is computable from a finite list of
   external variables and internal variables.

   Currently, in fact, every internal variable is a linear combination of
   external variables and previously generated internal variables.
*)

  (* TODO: shouldn't this be defined outside of V? What does V mean here? Varaible perhaps? *)
  module T = struct
    type t = External of int | Internal of Internal_var.t
    [@@deriving compare, hash, sexp]
  end

  include T
  include Comparable.Make (T)
  include Hashable.Make (T)
end

type ('a, 'f) t =
  { (* map of cells that share the same value (enforced by to the permutation) *)
    equivalence_classes : Row.t Position.t list V.Table.t
  ; (* How to compute each internal variable (as a linear combination of other variables) *)
    internal_vars : (('f * V.t) list * 'f option) Internal_var.Table.t
  ; (* ?, in reversed order because functional programming *)
    mutable rows_rev : V.t option array list
  ; (* a circuit is described by a series of gates. A gate is finalized if TKTK *)
    mutable gates :
      [ `Finalized | `Unfinalized_rev of (unit, 'f) Gate_spec.t list ]
  ; (* an instruction pointer *)
    mutable next_row : int
  ; (* hash of the circuit, for distinguishing different circuits *)
    mutable hash : Hash_state.t
  ; (* ? *)
    mutable constraints : int
  ; (* the size of the public input (which fills the first rows of our constraint system *)
    public_input_size : int Core_kernel.Set_once.t
  ; (* whatever is not public input *)
    mutable auxiliary_input_size : int
  }

module Hash = Core.Md5

(* the hash of the circuit *)
let digest (t : _ t) = Hash_state.digest t.hash

(* TODO: shouldn't that Make create something bounded by a signature? As we know what a back end should be? Check where this is used *)

(* TODO: glossary of terms in this file (terms, reducing, feeding) + module doc *)

(* TODO: rename Fp to F or something *)

(** ? *)
module Make
    (Fp : Field.S)
    (* TODO: why is there a type for gate vector, instead of using Gate.t list? *)
    (Gates : Gate_vector_intf with type field := Fp.t)
    (Params : sig
      val params : Fp.t Params.t
    end) =
struct
  open Core
  open Pickles_types

  type nonrec t = (Gates.t, Fp.t) t

  module H = Digestif.SHA256

  (** Used as a helper to unambiguously hash the circuit *)
  let feed_constraint t constr =
    (* TODO: does to_bytes always return a fixed-size response? That invariant should be checked somewhere (e.g. by checking that `zero |> to_bytes` returns something of the appropriate length )*)
    let absorb_field field acc = H.feed_bytes acc (Fp.to_bytes field) in
    let lc =
      (* TODO: Bytes.of_char_list ['\x00', '\x00', '\x00', ...]*)
      let int_buf = Bytes.init 8 ~f:(fun _ -> '\000') in
      fun x t ->
        List.fold x ~init:t ~f:(fun acc (x, index) ->
            let acc = absorb_field x acc in
            for i = 0 to 7 do
              Bytes.set int_buf i
                (Char.of_int_exn ((index lsr (8 * i)) land 255))
            done ;
            H.feed_bytes acc int_buf)
    in
    let cvars xs =
      List.concat_map xs ~f:(fun x ->
          let c, ts =
            Fp.(
              Snarky_backendless.Cvar.to_constant_and_terms x ~equal ~add ~mul
                ~zero ~one)
          in
          Option.value_map c ~default:[] ~f:(fun c -> [ (c, 0) ]) @ ts)
      |> lc
    in
    match constr with
    | Snarky_backendless.Constraint.Equal (v1, v2) ->
        let t = H.feed_string t "equal" in
        cvars [ v1; v2 ] t
    | Snarky_backendless.Constraint.Boolean b ->
        let t = H.feed_string t "boolean" in
        cvars [ b ] t
    | Snarky_backendless.Constraint.Square (x, z) ->
        let t = H.feed_string t "square" in
        cvars [ x; z ] t
    | Snarky_backendless.Constraint.R1CS (a, b, c) ->
        let t = H.feed_string t "r1cs" in
        cvars [ a; b; c ] t
    | Plonk_constraint.T constr -> (
        match constr with
        | Basic { l; r; o; m; c } ->
            let t = H.feed_string t "basic" in
            let pr (s, x) acc = absorb_field s acc |> cvars [ x ] in
            t |> pr l |> pr r |> pr o |> absorb_field m |> absorb_field c
        | Poseidon { state } ->
            let t = H.feed_string t "poseidon" in
            let row a = cvars (Array.to_list a) in
            Array.fold state ~init:t ~f:(fun acc a -> row a acc)
        | EC_add_complete { p1; p2; p3; result_infinite } ->
            let t = H.feed_string t "ec_add_complete" in
            let pr (x, y) = cvars [ x; y ] in
            t |> cvars [ result_infinite ] |> pr p1 |> pr p2 |> pr p3
        | EC_scale { state } ->
            let t = H.feed_string t "ec_scale" in
            Array.fold state ~init:t
              ~f:(fun acc { xt; b; yt; xp; l1; yp; xs; ys } ->
                cvars [ xt; b; yt; xp; l1; yp; xs; ys ] acc)
        | EC_endoscale { state } ->
            let t = H.feed_string t "ec_endoscale" in
            Array.fold state ~init:t
              ~f:(fun
                   acc
                   { xt; yt; xp; yp; n_acc; xr; yr; s1; s3; b1; b2; b3; b4 }
                 ->
                cvars
                  [ xt; yt; xp; yp; n_acc; xr; yr; s1; s3; b1; b2; b3; b4 ]
                  acc) )
    | _ ->
        failwith "Unsupported constraint"

  (* TODO: why isn't external_values an array instead? *)

  (** Compute the witness, given the constraint system `sys` and a function that converts the indexed secret inputs to their concrete values *)
  let compute_witness (sys : t) (external_values : int -> Fp.t) :
      Fp.t array array =
    let internal_values : Fp.t Internal_var.Table.t =
      Internal_var.Table.create ()
    in
    let public_input_size = Set_once.get_exn sys.public_input_size [%here] in
    let num_rows = Constants.zk_rows + public_input_size + sys.next_row in
    let res = Array.init num_rows ~f:(fun _ -> Array.create ~len:3 Fp.zero) in
    for i = 0 to public_input_size - 1 do
      res.(i).(0) <- external_values (i + 1)
    done ;
    let find t k =
      match Hashtbl.find t k with
      | None ->
          failwithf !"Could not find %{sexp:Internal_var.t}\n%!" k ()
      | Some x ->
          x
    in
    let compute ((lc, c) : (Fp.t * V.t) list * Fp.t option) =
      List.fold lc ~init:(Option.value c ~default:Fp.zero) ~f:(fun acc (s, x) ->
          let x =
            match x with
            | External x ->
                external_values x
            | Internal x ->
                find internal_values x
          in
          Fp.(acc + (s * x)))
    in
    List.iteri (List.rev sys.rows_rev) ~f:(fun i_after_input row ->
        let i = i_after_input + public_input_size in
        Array.iteri row ~f:(fun j v ->
            match v with
            | None ->
                ()
            | Some (External v) ->
                res.(i).(j) <- external_values v
            | Some (Internal v) ->
                let lc = find sys.internal_vars v in
                let value = compute lc in
                res.(i).(j) <- value ;
                Hashtbl.set internal_values ~key:v ~data:value)) ;
    for r = 0 to Constants.zk_rows - 1 do
      for c = 0 to 2 do
        res.(num_rows - 1 - r).(c) <- Fp.random ()
      done
    done ;
    res

  (** Creates an internal variable and assigns it the value lc and constant *)
  let create_internal ?constant sys lc : V.t =
    let v = Internal_var.create () in
    Hashtbl.add_exn sys.internal_vars ~key:v ~data:(lc, constant) ;
    V.Internal v

  (* returns a hash of the circuit *)
  let digest (sys : t) = Hash_state.digest sys.hash

  (* initializes a constraint system *)
  let create () : t =
    { public_input_size = Set_once.create ()
    ; internal_vars = Internal_var.Table.create ()
    ; gates = `Unfinalized_rev [] (* Gates.create () *)
    ; rows_rev = []
    ; next_row = 0
    ; equivalence_classes = V.Table.create ()
    ; hash = Hash_state.empty
    ; constraints = 0
    ; auxiliary_input_size = 0
    }

  (* TODO *)
  let to_json _ = `List []

  (** returns the number of auxiliary inputs *)
  let get_auxiliary_input_size t = t.auxiliary_input_size

  (** returns the number of public inputs *)
  let get_primary_input_size t = Set_once.get_exn t.public_input_size [%here]

  (* TODO: are these the private input? *)
  let set_auxiliary_input_size t x = t.auxiliary_input_size <- x

  (** sets the number of public-input. It must and can only be called once. *)
  let set_primary_input_size (sys : t) num_pub_inputs =
    Set_once.set_exn sys.public_input_size [%here] num_pub_inputs

  (* TODO: remove this no? isn't that a no-op? *)
  let digest = digest

  (** Adds {row; col} to the system's wiring under a specific key.
      A key is an external or internal variable.
      The row must be given relative to the start of the circuit 
      (so at the start of the public-input rows). *)
  let wire' sys key row (col : int) =
    let prev =
      match V.Table.find sys.equivalence_classes key with
      | Some x -> (
          match List.hd x with
          | Some x ->
              x
          | None ->
              { row; col } (* TODO: rewrite with | Some [] -> | Some x :: _ *) )
      | None ->
          (* not connected to anything *)
          { row; col }
    in
    V.Table.add_multi sys.equivalence_classes ~key ~data:{ row; col } ;
    prev

  (* TODO: rename to wire_abs and wire_rel? *)

  (** Same as wire', except that the row must be given relatively to the end of the public-input rows *)
  let wire sys key row col = wire' sys key (Row.After_public_input row) col

  let permutation =
    let module Relative_position = struct
      module T = struct
        type t = Row.t Position.t [@@deriving hash, sexp, compare]
      end

      include Core_kernel.Hashable.Make (T)
    end in
    fun ~(equivalence_classes : Row.t Position.t list V.Table.t) ->
      let res = Relative_position.Table.create () in
      Hashtbl.iter equivalence_classes ~f:(fun ps ->
          List.iter2_exn ps (List.last_exn ps :: List.tl_exn ps)
            ~f:(fun input output -> Hashtbl.add_exn res ~key:input ~data:output)) ;
      res

  let permutation_columns = 7

  (** Adds zero-knowledgeness to the gates/rows, and convert into Rust type [Gates.t].
      This can only be called once *)
  let finalize_and_get_gates sys =
    match sys.gates with
    | `Finalized ->
        failwith "Already finalized"
    | `Unfinalized_rev gates ->
        let rust_gates = Gates.create () in
        let public_input_size =
          Set_once.get_exn sys.public_input_size [%here]
        in
        (* First, add gates for public input *)
        let pub_selectors = [| Fp.one; Fp.zero; Fp.zero; Fp.zero; Fp.zero |] in
        let pub_input_gate_specs_rev = ref [] in
        for row = 0 to public_input_size - 1 do
          let lp = wire' sys (V.External (row + 1)) (Row.Public_input row) 0 in
          let lp_row = Row.to_absolute ~public_input_size lp.row in
          let public_gate =
            let lp = Position.{ row = lp_row; col = lp.col } in
            Position.append_cols row [| lp |]
          in
          pub_input_gate_specs_rev :=
            { Gate_spec.kind = Generic
            ; row = lp_row
            ; wired_to = public_gate
            ; coeffs = pub_selectors
            }
            :: !pub_input_gate_specs_rev
        done ;
        let permutation : Row.t Position.t -> int Position.t =
          let perm = permutation ~equivalence_classes:sys.equivalence_classes in
          fun pos ->
            let pos' = Hashtbl.find_exn perm pos in
            { pos' with row = Row.to_absolute pos'.row ~public_input_size }
        in
        (* Add zero-knowledge rows/gates at the very end *)
        let all_gates =
          let rev_mapi_append xs tl ~f =
            List.foldi xs ~init:tl ~f:(fun i acc x -> f i x :: acc)
          in
          let to_absolute_rows =
            Gate_spec.map_rows ~f:(Row.to_absolute ~public_input_size)
          in
          let random_rows =
            let coeffs = Array.init 5 ~f:(fun _ -> Fp.zero) in
            List.init Constants.zk_rows ~f:(fun i ->
                let row = Row.After_public_input (sys.next_row + i) in
                let wired_to = Position.create_cols row in
                to_absolute_rows { kind = Generic; row; wired_to; coeffs })
          in
          List.rev_append !pub_input_gate_specs_rev
            (rev_mapi_append gates random_rows ~f:(fun i g ->
                 let curr_row = Row.After_public_input i in
                 let () = g.row in
                 { g with
                   row = Row.to_absolute ~public_input_size curr_row
                 ; wired_to =
                     Array.init permutation_columns ~f:(fun i ->
                         permutation { row = curr_row; col = i })
                 }))
        in
        (* Convert all the gates into our Gates.t Rust vector type *)
        List.iter all_gates ~f:(fun g ->
            Gates.add rust_gates (Gate_spec.to_rust_gate g)) ;
        (* Return the zero-knowledgized gates *)
        rust_gates

  (** Calls [finalize_and_get_gates] and ignores the result. *)
  let finalize t = ignore (finalize_and_get_gates t : Gates.t)

  (** Regroup terms that share the same variable. 
      For example, (3, i2) ; (2, i2) can be simplified to (5, i2).
      It assumes that the list of given terms is sorted, 
      and that i0 is the smallest one.
      For example, `i0 = 1` and `terms = [(_, 2); (_, 2); (_; 4); ...]`

      Returns `(last_scalar, last_variable, terms, terms_length)`
      where terms does not contain the last scalar and last variable observed.
  *)
  let accumulate_sorted_terms (c0, i0) terms =
    Sequence.of_list terms
    |> Sequence.fold ~init:(c0, i0, [], 0) ~f:(fun (acc, i, ts, n) (c, j) ->
           if Int.equal i j then (Fp.add acc c, i, ts, n)
           else (c, j, (acc, i) :: ts, n + 1))

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
    let terms =
      List.sort terms ~compare:(fun (_, i) (_, j) -> Int.compare i j)
    in
    let has_constant_term = Option.is_some c in
    (* TODO: shouldn't the constant term be (1, c) instead? *)
    let terms = match c with None -> terms | Some c -> (c, 0) :: terms in
    match terms with
    | [] ->
        Some ([], 0, false)
    | t0 :: terms ->
        let acc, i, ts, n = accumulate_sorted_terms t0 terms in
        Some (List.rev ((acc, i) :: ts), n + 1, has_constant_term)

  (** Adds a row/gate/constraint to a constraint system `sys` *)
  let add_row sys row kind coeffs =
    match sys.gates with
    | `Finalized ->
        failwith "add_row called on finalized constraint system"
    | `Unfinalized_rev gates ->
        let open Position in
        sys.gates <-
          `Unfinalized_rev ({ kind; row = (); wired_to = [||]; coeffs } :: gates) ;
        sys.next_row <- sys.next_row + 1 ;
        sys.rows_rev <- row :: sys.rows_rev

  (* TODO: add more granular functions than general add_generic_constraint? *)

  (** Adds a generic constraint to the constraint system. *)
  let add_generic_constraint ?l ?r ?o coeffs sys : unit =
    let next_row = sys.next_row in
    let lp =
      match l with
      | Some lx ->
          wire sys lx next_row 0
      | None ->
          { row = After_public_input next_row; col = 0 }
    in
    let rp =
      match r with
      | Some rx ->
          wire sys rx next_row 1
      | None ->
          { row = After_public_input next_row; col = 1 }
    in
    let op =
      match o with
      | Some ox ->
          wire sys ox next_row 2
      | None ->
          { row = After_public_input next_row; col = 2 }
    in
    let row = Row.After_public_input next_row in
    let wired_to = Position.append_cols row [| lp; rp; op |] in
    add_row sys [| l; r; o |] Generic wired_to coeffs

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
    let terms =
      List.sort terms ~compare:(fun (_, i) (_, j) -> Int.compare i j)
    in
    match (constant, terms) with
    | Some c, [] ->
        (c, `Constant)
    | None, [] ->
        (Fp.zero, `Constant)
    | _, t0 :: terms -> (
        let terms =
          let acc, i, ts, _ = accumulate_sorted_terms t0 terms in
          List.rev ((acc, i) :: ts)
        in
        match terms with
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
        Snarky_backendless.Constraint.basic) =
    sys.hash <- feed_constraint sys.hash constr ;
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
      | s, `Constant ->
          let x = create_internal sys ~constant:s [] in
          add_generic_constraint ~l:x
            [| Fp.one; Fp.zero; Fp.zero; Fp.zero; Fp.negate s |]
            sys ;
          x
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
            (* s1 x1 - s2 x2 = 0
          *)
            if not (Fp.equal s1 s2) then
              add_generic_constraint ~l:x1 ~r:x2
                [| s1; Fp.(negate s2); Fp.zero; Fp.zero; Fp.zero |]
                sys
              (* TODO: optimize by not adding generic costraint but rather permuting the vars *)
            else
              add_generic_constraint ~l:x1 ~r:x2
                [| s1; Fp.(negate s2); Fp.zero; Fp.zero; Fp.zero |]
                sys
        | `Var x1, `Constant ->
            add_generic_constraint ~l:x1
              [| s1; Fp.zero; Fp.zero; Fp.zero; Fp.negate s2 |]
              sys
        | `Constant, `Var x2 ->
            add_generic_constraint ~r:x2
              [| Fp.zero; s2; Fp.zero; Fp.zero; Fp.negate s1 |]
              sys
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
        let add_round_state state_i ind =
          let row = Array.map state_i ~f:(fun x -> Some x) in
          let wired_to =
            Array.mapi state_i ~f:(fun i x -> wire sys x sys.next_row i)
            |> Position.cols_to_perms
          in
          let coeffs = Params.params.round_constants.(ind + 1) in
          add_row sys row Poseidon wired_to coeffs
        in
        (* iterate through the state *)
        let last_row = Array.length state - 1 in
        Array.iteri state ~f:(fun i state_i ->
            if i <> last_row then add_round_state state_i i
            else
              (* last row is zero gate, only the first three columns matter *)
              let row =
                [| Some state_i.(0)
                 ; Some state_i.(1)
                 ; Some state_i.(2)
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
              let wired_to =
                Position.append_cols (Row.After_public_input sys.next_row)
                  [| wire sys state_i.(0) sys.next_row 0
                   ; wire sys state_i.(1) sys.next_row 1
                   ; wire sys state_i.(2) sys.next_row 2
                  |]
              in
              let coeffs = [||] in
              add_row sys row Zero wired_to coeffs)
    | Plonk_constraint.T
        (EC_add_complete { p1; p2; p3; inf; same_x; slope; inf_z; x21_inv }) ->
        let reduce_curve_point (x, y) = (reduce_to_v x, reduce_to_v y) in

        (*
        //! 0   1   2   3   4   5   6   7      8   9      10      11   12   13   14
        //! x1  y1  x2  y2  x3  y3  inf same_x s   inf_z  x21_inv

        *)
        let x1, y1 = reduce_curve_point p1 in
        let x2, y2 = reduce_curve_point p1 in
        let x3, y3 = reduce_curve_point p1 in
        let row =
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
        let wired_to =
          Position.append_cols (Row.After_public_input sys.next_row)
            [| wire sys x1 sys.next_row 0
             ; wire sys y1 sys.next_row 1
             ; wire sys x2 sys.next_row 2
             ; wire sys y2 sys.next_row 3
             ; wire sys x3 sys.next_row 4
             ; wire sys y3 sys.next_row 5
            |]
        in
        add_row sys row EcAddComplete wired_to [||]
    | Plonk_constraint.T (EC_scale { state }) ->
        let i = ref 0 in
        let add_ecscale_round (round : V.t Scale_round.t) =
          let xt = wire sys round.xt sys.next_row L in
          let b = wire sys round.b sys.next_row R in
          let yt = wire sys round.yt sys.next_row O in
          let xp = wire sys round.xp (sys.next_row + 1) L in
          let l1 = wire sys round.l1 (sys.next_row + 1) R in
          let yp = wire sys round.yp (sys.next_row + 1) O in
          let xs = wire sys round.xs (sys.next_row + 2) L in
          let xt1 = wire sys round.xt (sys.next_row + 2) R in
          let ys = wire sys round.ys (sys.next_row + 2) O in
          add_row sys
            [| Some round.xt; Some round.b; Some round.yt |]
            Vbmul1 xt b yt [||] ;
          add_row sys
            [| Some round.xp; Some round.l1; Some round.yp |]
            Vbmul2 xp l1 yp [||] ;
          add_row sys
            [| Some round.xs; Some round.xt; Some round.ys |]
            Vbmul3 xs xt1 ys [||]
        in
        Array.iter
          ~f:(fun round -> add_ecscale_round round ; incr i)
          (Array.map state ~f:(Scale_round.map ~f:reduce_to_v)) ;
        ()
    | Plonk_constraint.T (EC_endoscale { state }) ->
        let add_endoscale_round (round : V.t Endoscale_round.t) =
          let xt = wire sys round.xt sys.next_row 0 in
          let yt = wire sys round.xt sys.next_row 1 in
          let xp = wire sys round.xt sys.next_row 4 in
          let yp = wire sys round.xt sys.next_row 5 in
          let n_acc = wire sys round.n_acc sys.next_row 6 in
          let xr = wire sys round.xr sys.next_row 7 in
          let yr = wire sys round.yr sys.next_row 8 in
          let s1 = wire sys round.s1 sys.next_row 9 in
          let s3 = wire sys round.s3 sys.next_row 10 in
          let b1 = wire sys round.b1 sys.next_row 11 in
          let b2 = wire sys round.b2 sys.next_row 12 in
          let b3 = wire sys round.b3 sys.next_row 13 in
          let b4 = wire sys round.b4 sys.next_row 14 in
          add_row sys
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
            Kimchi.Protocol.Endomul
            [| xt
             ; yt
             ; { row = After_public_input sys.next_row; col = 2 }
             ; { row = After_public_input sys.next_row; col = 3 }
             ; xp
             ; yp
             ; n_acc
             ; xr
             ; yr
             ; s1
             ; s3
             ; b1
             ; b2
             ; b3
             ; b4
            |]
            [||]
        in
        let state = Array.map state ~f:(Endoscale_round.map ~f:reduce_to_v) in
        let last_row = Array.length state - 1 in
        Array.iteri state ~f:(fun i round ->
            if i <> last_row then add_endoscale_round round
            else
              let row =
                [| None
                 ; None
                 ; None
                 ; None
                 ; Some round.xp
                 ; Some round.yp
                 ; Some round.n_acc
                 ; None
                 ; None
                 ; None
                 ; None
                 ; None
                 ; None
                 ; None
                |]
              in
              let wired_to =
                Position.create_cols (Row.After_public_input sys.next_row)
              in
              wired_to.(4) <- wire sys round.xp sys.next_row 4 ;
              wired_to.(5) <- wire sys round.yp sys.next_row 5 ;
              wired_to.(6) <- wire sys round.n_acc sys.next_row 6 ;
              let coeffs = [||] in
              add_row sys row Zero wired_to coeffs)
    | constr ->
        failwithf "Unhandled constraint %s"
          Obj.(Extension_constructor.name (Extension_constructor.of_val constr))
          ()
end
