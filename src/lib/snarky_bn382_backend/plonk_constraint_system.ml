module Internal_id = Core_kernel.Unique_id.Int ()

module Make (Fp : Field.S) = struct
  open Core_kernel

  module Column = struct
    module T = struct
      type t = A | B | C [@@deriving sexp, compare]
    end

    include T
    include Comparable.Make (T)
  end

  module Position = struct
    type t = {row: int; col: Column.t}
  end

  module Var = struct
    module T = struct
      type t = Surface of int | Internal of Internal_id.t
      [@@deriving sexp, hash]

      (* We define compare explicitly because we use the fact that
         Surface 0 is the least element. *)
      let compare t1 t2 =
        match (t1, t2) with
        | Surface i, Surface j ->
            Int.compare i j
        | Internal i, Internal j ->
            Internal_id.compare i j
        | Surface _, Internal _ ->
            -1
        | Internal _, Surface _ ->
            1
    end

    include T
    include Comparable.Make (T)
    include Hashable.Make (T)

    let fresh () = Internal (Internal_id.create ())
  end

  module Monomial = struct
    module T = struct
      type t = One | A | B | C | AA | BB | CC | AB | AC | BC
      [@@deriving sexp, compare]
    end

    include T
    include Comparable.Make (T)

    let of_column : Column.t -> t = function A -> A | B -> B | C -> C
  end

  module Row_polynomial = struct
    type t = Fp.t Monomial.Map.t

    let ( - ) : t -> t -> t =
      Map.merge ~f:(fun ~key t ->
          let z =
            match t with
            | `Both (x, y) ->
                Fp.(x - y)
            | `Left x ->
                x
            | `Right y ->
                Fp.negate y
          in
          if Fp.equal z Fp.zero then None else Some z )
  end

  module Lc = struct
    module Constant_separated = struct
      type t = Fp.t option * (Fp.t * Var.t) list

      let of_cvar v : t =
        let c, t =
          Fp.(Snarky.Cvar.to_constant_and_terms v ~equal ~add ~mul ~zero ~one)
        in
        (c, List.map t ~f:(fun (c, v) -> (c, Var.Surface v)))
    end

    type t = (Fp.t * Var.t) list

    let combine ((c, ts) : Constant_separated.t) : t =
      match c with None -> ts | Some c -> (c, Var.Surface 0) :: ts

    let separate : t -> Constant_separated.t = function
      | [] ->
          (None, [])
      | (c, Var.Surface 0) :: ts ->
          (Some c, ts)
      | _ :: _ as ts ->
          (None, ts)

    let of_cvar = Fn.compose combine Constant_separated.of_cvar

    let mul : Column.t Var.Map.t -> t -> t -> Row_polynomial.t =
     fun m t1 t2 ->
      let m i =
        let r = Map.find m i in
        if Option.is_none r then assert (i = Var.Surface 0) ;
        r
      in
      let accum_term acc (v, c) =
        Map.update acc v ~f:(function None -> c | Some a -> Fp.(a * c))
      in
      Sequence.(
        fold ~init:Monomial.Map.empty ~f:accum_term
          Let_syntax.(
            let%map c1, x1 = of_list t1 and c2, x2 = of_list t2 in
            let v =
              match (m x1, m x2) with
              | None, None ->
                  Monomial.One
              | Some c, None | None, Some c ->
                  Monomial.of_column c
              | Some x1, Some x2 -> (
                match (x1, x2) with
                | A, A | B, B ->
                    BB
                | C, C ->
                    CC
                | A, B | B, A ->
                    AB
                | A, C | C, A ->
                    AC
                | B, C | C, B ->
                    BC )
            in
            (v, Fp.(c1 * c2))))

    let to_row_polynomial : Column.t Var.Map.t -> t -> Row_polynomial.t =
      let one : t = [(Fp.one, Var.Surface 0)] in
      Fn.flip mul one
  end

  module Row = Row_polynomial

  type t =
    { mutable rows: Row.t list (* Length of rows *)
    ; mutable n: int
    ; vars: Position.t list Var.Table.t }

  let create () = {rows= []; n= 0; vars= Var.Table.create ()}

  let add_row t ~a ~b ~c row =
    let i = t.n in
    let add col v = Hashtbl.add_multi t.vars ~key:v ~data:{row= i; col} in
    add A a ;
    add B b ;
    add C c ;
    t.n <- t.n + 1 ;
    t.rows <- row :: t.rows

  let add_row' t (m : Column.t Var.Map.t) row =
    let i = t.n in
    Map.iteri m ~f:(fun ~key ~data:col ->
        Hashtbl.add_multi t.vars ~key ~data:{row= i; col} ) ;
    t.n <- t.n + 1 ;
    t.rows <- row :: t.rows

  let fits_in_row : Var.t list -> Column.t Var.Map.t option =
   fun xs ->
    let z, r = List.zip_with_remainder xs [Column.A; B; C] in
    match r with
    | None | Some (Second (_ : Column.t list)) ->
        Some (Var.Map.of_alist_exn z)
    | Some (First _) ->
        None

  let indices (termss : Lc.t list) : Var.t list =
    match
      List.dedup_and_sort ~compare:Var.compare
        (List.concat_map termss ~f:(List.map ~f:snd))
    with
    (* Here is where we use the fact that Surface 0 is least. *)
    | Surface 0 :: ts ->
        ts
    | ts ->
        ts

  (* Given a set of linear combinations, we would like to "reduce" them until
   they have between them only 3 variables.
   
   By reducing a linear combination sum_i a_i x_i, we mean allocating a
   fresh internal variable x_new, picking indices i_1, i_2, constraining

   a_{i_1} x_1 + a_{i_2} x_2 = x_new

   and setting the linear combination to be

   x_new + sum_{i \neq i_1, i_2} a_i x_i.

   We want to perform as few reductions as possible to get the linear combinations
   to have only three variables between them.

   To introduce a bit of notation, for [lc : Lc.t] define
   [vars lc : Var.Set.t] to be the set of variables in [lc].
   For [lcs : Lc.t list], define [vars lcs : Var.Set.t] as the
   union of [vars lc] for [lc] in [lcs]. 

   Given [lcs : Lc.t list], we need to repeatedly reduce it until
   [Set.length (vars lcs) <= 3].

   For now, we just pursue the simple method of individually reducing each
   linear combination to a single variable, unless [Set.length (vars lcs)] is
   already <= 3.

   This could definitely be improved if some of the linear combinations in
   [lcs] consist only of (at most 2) "common" variables, that is, of variables present in
   all other linear combinations in lcs.
*)

  let neg_one = Fp.(negate one)

  let reduce_one (t : t) (lc : Lc.t) : Lc.t option =
    match Lc.separate lc with
    | _, [] | _, [_] ->
        None
    | c0, (c1, v1) :: (c2, v2) :: ts ->
        (* Also no harm in eliminating the constant in this reduction. *)
        let v_new = Var.fresh () in
        add_row t ~a:v1 ~b:v2 ~c:v_new
          (* c1 A + c2 B + c0 - C = 0 *)
          (Monomial.Map.of_alist_exn
             ( [(Monomial.A, c1); (B, c2); (C, neg_one)]
             @ Option.value_map c0 ~default:[] ~f:(fun c0 ->
                   [(Monomial.One, c0)] ) )) ;
        Some ((Fp.one, v_new) :: ts)

  let rec until_none (x : 'a) ~(f : 'a -> 'a option) : 'a =
    match f x with None -> x | Some y -> until_none y ~f

  (* A LC is totally reduced if it contains at most 1 non-constant variable. *)
  let rec reduce_lc (t : t) (lc : Lc.t) : Lc.t =
    until_none lc ~f:(reduce_one t)

  open Pickles_types

  let fits_in_row lcs = fits_in_row (indices (Vector.to_list lcs))

  (* This only works for vectors of length <= 3 *)
  let reduce_lcs (type n) (t : t) (lcs : (Lc.t, n) Vector.t) :
      (Lc.t, n) Vector.t * Column.t Var.Map.t =
    match fits_in_row lcs with
    | Some var_to_col ->
        (lcs, var_to_col)
    | None ->
        let lcs = Vector.map lcs ~f:(reduce_lc t) in
        (* After reduction, it should fit in the row. *)
        (lcs, Option.value_exn (fits_in_row lcs))

  let reduce_cvars t vs = reduce_lcs t (Vector.map ~f:Lc.of_cvar vs)

  let add_constraint t (constr : Fp.t Snarky.Cvar.t Snarky.Constraint.basic) :
      unit =
    match constr with
    | Boolean v ->
        let [v], m = reduce_cvars t [v] in
        add_row' t m Row_polynomial.(Lc.mul m v v - Lc.to_row_polynomial m v)
    | Square (v1, v2) ->
        let [v1; v2], m = reduce_cvars t [v1; v2] in
        add_row' t m
          Row_polynomial.(Lc.mul m v1 v1 - Lc.to_row_polynomial m v2)
    | R1CS (v1, v2, v3) ->
        let [v1; v2; v3], m = reduce_cvars t [v1; v2; v3] in
        add_row' t m
          Row_polynomial.(Lc.mul m v1 v2 - Lc.to_row_polynomial m v3)
    | Equal (v1, v2) ->
        let v0, m =
          let v0 = Lc.of_cvar Snarky.Cvar.(Add (v1, Scale (neg_one, v2))) in
          match fits_in_row [v0] with
          | Some var_to_col ->
              (v0, var_to_col)
          | None ->
              (* Because we only have one lc, we can stop reduction when
             it itself contains at most three distinct variables. *)
              let reduce_one' lc =
                match Lc.separate lc with
                | _, ([] | [_] | [_; _] | [_; _; _]) ->
                    None
                | _ ->
                    reduce_one t lc
              in
              let v0 = until_none v0 ~f:reduce_one' in
              (v0, Option.value_exn (fits_in_row [v0]))
        in
        add_row' t m (Lc.to_row_polynomial m v0)

  (* If a variable is omitted from a constraint, it can be omitted from
   the multiexp if we precompute lagrange basis commitments *)

  (*
(* If each constraint has at most 3 actual variables in it, we can do 1r1cs = 1plonk *)
  let add_constraint t
      (constr : Fp.t Snarky.Cvar.t Snarky.Constraint.basic) =
    (a1 + b1 x1)^2 = a1 + b1 x1

    a1^2 + b1^2 x1^2 + 2 a1 b1 x1
    = a1 + b1 x1

    (a1^2 - a1) + b1^2 x1^2 + (2 a1 b1 - b1) x1
    = 0

    match constr with
    | Boolean b ->
      begin match
          Fp.(Snarky.Cvar.to_constant_and_terms b ~equal
            ~add ~mul ~zero ~one)
        with
        | Constant _ -> ()
      end;
      t.vars
     *)
end

(*

  let rec reduce_constraint (type n)
      : t -> (Lc.t, n) Vector.t -> (Lc.t, n) Vector.t * Column.t Var.Map.t
    =
    let module Lc_set = struct
      type t =
        { lcs: Lc.t array
        (* Sorted by the length of the list *)
        ; occurrences: (Var.t, int list) List.Assoc.t
        }
    end
    in
    let reduce v lc =
    in
    let rec reduce_set (t : t) ({ lcs; occurrences } : Lc_set.t) =
      match fits_in_row (indices (Array.to_list lcs)) with
      | Some var_to_col -> (lcs, var_to_col)
      | None ->
        match occurrences with
        | [] -> assert false
        | (v, i :: is_v) :: occurrences ->
          (* Reduce v in LC i *)
          let lc_i = lcs.(i) in

        (* Reduce the entry that has a unique Var in it so that we decrease
          the number of distinct Vars across the vector *)
        (* Record the indices in the vector that each variable appears in. *)
        let vars_to_indices =
          Var.Map.of_alist_multi
            (List.concat_mapi (Vector.to_list ts) ~f:(fun i t ->
                List.map t ~f:(fun (_, v) -> (v, i))))
        in
        (* Eliminate the Var that has the smallest number of occurrences. *)
        let to_reduce =
          let open Sequence in
          map (Map.to_sequence vars_to_indices)
            ~f:(fun (v, is) -> (v, is, List.length is))

              (*
            ~f:(fun (v, is) ->
                match is with
                | [i] -> Some (i, v)
                | _ -> None ) *)
        in
        (* Recursing at this point is pretty wasteful, since we know we're
          just going to keep reducing that same var, so if this is slow this
          would be a good place to optimize. *)
        vars_to_indices
*)
