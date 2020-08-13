module Hash_state = struct
  open Core_kernel
  module H = Digestif.SHA256

  type t = H.ctx

  let digest t = Md5.digest_string H.(to_raw_string (get t))
end

module Plonk_constraint = struct
  open Core_kernel

  module T = struct
    type ('v, 'f) t =
      | Basic of { l : 'f * 'v; r : 'f * 'v; o : 'f * 'v; m: 'f; c: 'f }
      | Poseidon_rounds of { num_rounds: int; start: 'v array; finish: 'v array }
    [@@deriving sexp]

    let map (type a b f) (t : (a, f) t) ~(f : a -> b) =
      match t with
      | Basic { l ; r; o; m; c } ->
        let p (x, y) = (x, f y) in
        Basic { l= p l; r= p r; o= p o; m; c }
      | Poseidon_rounds { num_rounds; start; finish } ->
        Poseidon_rounds { num_rounds; start=Array.map ~f start; finish= Array.map ~f finish }

    let eval (type v f)
        (module F : Snarky_backendless.Field_intf.S with type t = f)
        (eval_one : v -> f)
        (t : (v, f) t) =
      match t with
      (* cl * vl + cr * vr + co * vo + m * vl*vr + c = 0 *)
      | Basic { l=(cl, vl); r=(cr, vr) ; o = (co, vo); m; c } ->
        let vl = eval_one vl in
        let vr = eval_one vr in
        let vo = eval_one vo in
        F.(equal zero (List.reduce_exn ~f:add [ mul cl vl; mul cr vl; mul co vo; mul m (mul vl vr); c ]))
      | _ -> failwith "TODO"
  end
  include Snarky_backendless.Constraint.Add_kind(T)
end 

module Position = struct
  type t = { row: int; col: int }
end

module Internal_var = Uuid

module V = struct
  open Core_kernel

  module T = struct
    type t =
      | External of int
      | Internal of Internal_var.Unstable.t
      [@@deriving compare, hash, sexp]
  end
  include T
  include Comparable.Make(T)
  include Hashable.Make(T)

  let create_internal () = Internal (Internal_var.create ())
end

type 'a t =
  { backend: 'a
  ; equivalence_classes: Position.t list V.Table.t
  ; mutable next_row: int
  ; mutable hash: Hash_state.t
  ; mutable public_input_size: int
  ; mutable auxiliary_input_size: int }

let digest (t : _ t) = Hash_state.digest t.hash

module Make (Fp : sig
  include Field.S

  val to_bigint_raw_noalloc : t -> Bigint.t
end) = struct
  open Core_kernel

(* variable type into linear combination of variables *)
  let canonicalize x =
    let c, terms =
      Fp.(
        Snarky_backendless.Cvar.to_constant_and_terms ~add ~mul ~zero:(of_int 0) ~equal
          ~one:(of_int 1))
        x
    in
    let terms =
      List.sort terms ~compare:(fun (_, i) (_, j) -> Int.compare i j)
    in
    let has_constant_term = Option.is_some c in
    let terms = match c with None -> terms | Some c -> (c, 0) :: terms in
    match terms with
    | [] ->
        Some ([], 0, false)
    | (c0, i0) :: terms ->
        let acc, i, ts, n =
          Sequence.of_list terms
          |> Sequence.fold ~init:(c0, i0, [], 0)
                ~f:(fun (acc, i, ts, n) (c, j) ->
                  if Int.equal i j then (Fp.add acc c, i, ts, n)
                  else (c, j, (acc, i) :: ts, n + 1) )
        in
        Some (List.rev ((acc, i) :: ts), n + 1, has_constant_term)

  module Hash_state = struct
    include Hash_state
  end

  let neg_one = Fp.(negate one)

  let add_generic_constraint sys ?mul ?constant
      ?output (**o *)
      ((s1: Fp.t), x1) ((s2 : Fp.t), x2) (**l, r *)
      : unit
    =
    let row = sys.next_row in
    sys.next_row <- row + 1 ;
    V.Table.add_multi sys.equivalence_classes ~key:x1
      ~data:{ row; col= 0 } ;
    V.Table.add_multi sys.equivalence_classes ~key:x1
      ~data:{ row; col= 1 } ;
    Option.iter output ~f:(fun (_, x3) ->
    V.Table.add_multi sys.equivalence_classes ~key:x3
        ~data:{ row; col= 2 } ) (*;
    Backend.add_generic_constraint
      sys.backend
      ([ s1; s2 ] @ Option.to_list (Option.map ~f:fst output) @ Option.to_list mul @ Option.to_list constant ) *)

  let completely_reduce sys (terms : (Fp.t * int) list) = (* just adding constrained variables without values *)
    let rec go = function
      | [] -> assert false
      | [ (s, x) ] -> (s, V.External x)
      | (s1, x1) :: t ->
        let x1 = V.External x1 in
        let (s2, x2) = go t in
        let s1x1_plus_s2x2 = V.create_internal () in
        add_generic_constraint sys
          (s1, x1) (s2, x2) ~output:(neg_one, s1x1_plus_s2x2) ;
        (Fp.one, s1x1_plus_s2x2)
    in
    go terms

  let reduce_lincom sys (x : Fp.t Snarky_backendless.Cvar.t)  =
    let constant, terms =
      Fp.(
        Snarky_backendless.Cvar.to_constant_and_terms ~add ~mul ~zero:(of_int 0) ~equal
          ~one:(of_int 1))
        x
    in
    let terms =
      List.sort terms ~compare:(fun (_, i) (_, j) -> Int.compare i j)
    in
    match constant, terms with
    | Some c, [] -> (c, `Constant)
    | None, [] -> (Fp.zero, `Constant)
    | _, (c0, i0) :: terms ->
      let terms =
        let acc, i, ts, _ =
          Sequence.of_list terms
          |> Sequence.fold ~init:(c0, i0, [], 0)
                ~f:(fun (acc, i, ts, n) (c, j) ->
                  if Int.equal i j then (Fp.add acc c, i, ts, n)
                  else (c, j, (acc, i) :: ts, n + 1) )
        in
        List.rev ((acc, i) :: ts)
      in
      match terms with
      | [] -> assert false
      | [(x, i)] -> (x, `Var (V.External i))
      | (s1, x1) :: tl ->
        let (s2, x2) = completely_reduce sys tl in
        let res = V.create_internal () in
        add_generic_constraint sys ?constant
          (s1, External x1) (s2, x2) ~output:(neg_one, res) ;
        (Fp.one, `Var res)
  ;;

  let add_constraint ?label:_ sys
      (constr : (Fp.t Snarky_backendless.Cvar.t, Fp.t) Snarky_backendless.Constraint.basic) =
    let var = canonicalize in
    let var_exn t = Option.value_exn (var t) in
    let red = reduce_lincom sys in
    match constr with
    | Snarky_backendless.Constraint.Boolean x ->
      let (s, x) = red x in
      (* s^2 x^2 = s x
         s x - s^2 x*x = 0
      *)
      begin match x with
      | `Constant -> 
        (* Nothing to do *)
        ()
      | `Var x ->
        add_generic_constraint sys
          ~mul:Fp.(negate (square s))
          (s, x)
          (s, x)
      end
    | Snarky_backendless.Constraint.R1CS (a, b, c) ->
      match (red a, red b, red c) with
      | _ -> ()
end
