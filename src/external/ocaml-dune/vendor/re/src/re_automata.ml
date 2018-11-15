(*
   RE - A regular expression library

   Copyright (C) 2001 Jerome Vouillon
   email: Jerome.Vouillon@pps.jussieu.fr

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation, with
   linking exception; either version 2.1 of the License, or (at
   your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
*)

module Cset = Re_cset

type sem = [ `Longest | `Shortest | `First ]

type rep_kind = [ `Greedy | `Non_greedy ]

type category = int
type mark = int
type idx = int

module Pmark : sig
  type t = private int
  val equal : t -> t -> bool
  val compare : t -> t -> int
  val gen : unit -> t
  val pp : Format.formatter -> t -> unit
end
= struct
  type t = int
  let equal (x : int) (y : int) = x = y
  let compare (x : int) (y : int) = compare x y
  let r = ref 0
  let gen () = incr r ; !r

  let pp = Format.pp_print_int
end

type expr = { id : int; def : def }

and def =
    Cst of Cset.t
  | Alt of expr list
  | Seq of sem * expr * expr
  | Eps
  | Rep of rep_kind * sem * expr
  | Mark of int
  | Erase of int * int
  | Before of category
  | After of category
  | Pmark of Pmark.t

module PmarkSet = Set.Make(Pmark)

let hash_combine h accu = accu * 65599 + h

module Marks = struct
  type t =
    { marks : (int * int) list
    ; pmarks : PmarkSet.t }

  let empty = { marks = [] ; pmarks = PmarkSet.empty }

  let rec merge_marks_offset old = function
    | [] ->
      old
    | (i, v) :: rem ->
      let nw' = merge_marks_offset (List.remove_assq i old) rem in
      if v = -2 then
        nw'
      else
        (i, v) :: nw'

  let merge old nw =
    { marks = merge_marks_offset old.marks nw.marks
    ; pmarks = PmarkSet.union old.pmarks nw.pmarks }

  let rec hash_marks_offset l accu =
    match l with
      []          -> accu
    | (a, i) :: r -> hash_marks_offset r (hash_combine a (hash_combine i accu))

  let hash m accu =
    hash_marks_offset m.marks (hash_combine (Hashtbl.hash m.pmarks) accu)

  let rec marks_set_idx idx = function
    | (a, -1) :: rem ->
      (a, idx) :: marks_set_idx idx rem
    | marks ->
      marks

  let marks_set_idx marks idx =
    { marks with marks = marks_set_idx idx marks.marks }

  let pp_marks ch t =
    match t.marks with
    | [] ->
      ()
    | (a, i) :: r ->
      Format.fprintf ch "%d-%d" a i;
      List.iter (fun (a, i) -> Format.fprintf ch " %d-%d" a i) r
end

(****)

let pp_sem ch k =
  Format.pp_print_string ch
    (match k with
       `Shortest -> "short"
     | `Longest  -> "long"
     | `First    -> "first")


let pp_rep_kind fmt = function
  | `Greedy -> Format.pp_print_string fmt "Greedy"
  | `Non_greedy -> Format.pp_print_string fmt "Non_greedy"

let rec pp ch e =
  let open Re_fmt in
  match e.def with
    Cst l ->
    sexp ch "cst" Cset.pp l;
  | Alt l ->
    sexp ch "alt" (list pp) l
  | Seq (k, e, e') ->
    sexp ch "seq" (triple pp_sem pp pp) (k, e, e')
  | Eps ->
    str ch "eps"
  | Rep (_rk, k, e) ->
    sexp ch "rep" (pair pp_sem pp) (k, e)
  | Mark i ->
    sexp ch "mark" int i
  | Pmark i ->
    sexp ch "pmark" int (i :> int)
  | Erase (b, e) ->
    sexp ch "erase" (pair int int) (b, e)
  | Before c ->
    sexp ch "before" int c
  | After c ->
    sexp ch "after" int c


(****)

let rec first f = function
  | [] ->
    None
  | x :: r ->
    match f x with
      None          -> first f r
    | Some _ as res -> res

(****)

type ids = int ref
let create_ids () = ref 0

let eps_expr = { id = 0; def = Eps }

let mk_expr ids def =
  incr ids;
  { id = !ids; def = def }

let empty ids = mk_expr ids (Alt [])

let cst ids s =
  if Re_cset.is_empty s
  then empty ids
  else mk_expr ids (Cst s)

let alt ids = function
  | []  -> empty ids
  | [c] -> c
  | l   -> mk_expr ids (Alt l)

let seq ids kind x y =
  match x.def, y.def with
    Alt [], _                 -> x
  | _, Alt []                 -> y
  | Eps, _                    -> y
  | _, Eps when kind = `First -> x
  | _                         -> mk_expr ids (Seq (kind, x, y))

let is_eps expr =
  match expr.def with
  | Eps -> true
  | _ -> false

let eps ids = mk_expr ids Eps

let rep ids kind sem x = mk_expr ids (Rep (kind, sem, x))

let mark ids m = mk_expr ids (Mark m)

let pmark ids i = mk_expr ids (Pmark i)

let erase ids m m' = mk_expr ids (Erase (m, m'))

let before ids c = mk_expr ids (Before c)

let after ids c = mk_expr ids (After c)

(****)

let rec rename ids x =
  match x.def with
    Cst _ | Eps | Mark _ | Pmark _ | Erase _ | Before _ | After _ ->
    mk_expr ids x.def
  | Alt l ->
    mk_expr ids (Alt (List.map (rename ids) l))
  | Seq (k, y, z) ->
    mk_expr ids (Seq (k, rename ids y, rename ids z))
  | Rep (g, k, y) ->
    mk_expr ids (Rep (g, k, rename ids y))

(****)

type hash = int
type mark_infos = int array
type status = Failed | Match of mark_infos * PmarkSet.t | Running

module E = struct
  type t =
    | TSeq of t list * expr * sem
    | TExp of Marks.t * expr
    | TMatch of Marks.t

  let rec equal l1 l2 =
    match l1, l2 with
    | [], [] ->
      true
    | TSeq (l1', e1, _) :: r1, TSeq (l2', e2, _) :: r2 ->
      e1.id = e2.id && equal l1' l2' && equal r1 r2
    | TExp (marks1, e1) :: r1, TExp (marks2, e2) :: r2 ->
      e1.id = e2.id && marks1 = marks2 && equal r1 r2
    | TMatch marks1 :: r1, TMatch marks2 :: r2 ->
      marks1 = marks2 && equal r1 r2
    | _ ->
      false

  let rec hash l accu =
    match l with
    | [] ->
      accu
    | TSeq (l', e, _) :: r ->
      hash r (hash_combine 0x172a1bce (hash_combine e.id (hash l' accu)))
    | TExp (marks, e) :: r ->
      hash r
        (hash_combine 0x2b4c0d77 (hash_combine e.id (Marks.hash marks accu)))
    | TMatch marks :: r ->
      hash r (hash_combine 0x1c205ad5 (Marks.hash marks accu))

  let texp marks x = TExp (marks, x)

  let tseq kind x y rem =
    match x with
      []                              -> rem
    | [TExp (marks, {def = Eps ; _})] -> TExp (marks, y) :: rem
    | _                               -> TSeq (x, y, kind) :: rem

  let rec print_state_rec ch e y =
    match e with
    | TMatch marks ->
      Format.fprintf ch "@[<2>(Match@ %a)@]" Marks.pp_marks marks
    | TSeq (l', x, _kind) ->
      Format.fprintf ch "@[<2>(Seq@ ";
      print_state_lst ch l' x;
      Format.fprintf ch " %a)@]" pp x
    | TExp (marks, {def = Eps; _}) ->
      Format.fprintf ch "(Exp %d (%a) (eps))" y.id Marks.pp_marks marks
    | TExp (marks, x) ->
      Format.fprintf ch "(Exp %d (%a) %a)" x.id Marks.pp_marks marks pp x

  and print_state_lst ch l y =
    match l with
      [] ->
      Format.fprintf ch "()"
    | e :: rem ->
      print_state_rec ch e y;
      List.iter
        (fun e ->
           Format.fprintf ch " | ";
           print_state_rec ch e y)
        rem

  let pp ch t = print_state_lst ch [t] { id = 0; def = Eps }
end

module State = struct
  type t =
    { idx: idx
    ; category: category
    ; desc: E.t list
    ; mutable status: status option
    ; hash: hash }

  let dummy =
    { idx = -1
    ; category = -1
    ; desc = []
    ; status = None
    ; hash = -1 }

  let hash idx cat desc =
    E.hash desc (hash_combine idx (hash_combine cat 0)) land 0x3FFFFFFF

  let mk idx cat desc = 
    { idx
    ; category = cat
    ; desc
    ; status = None
    ; hash = hash idx cat desc}

  let create cat e = mk 0 cat [E.TExp (Marks.empty, e)]

  let equal x y =
    (x.hash : int) = y.hash && (x.idx : int) = y.idx &&
    (x.category : int) = y.category && E.equal x.desc y.desc

  let compare x y =
    let c = compare (x.hash : int) y.hash in
    if c <> 0 then c else
      let c = compare (x.category : int) y.category in
      if c <> 0 then c else
        compare x.desc y.desc

  type t' = t
  module Table = Hashtbl.Make(
    struct
      type t = t'
      let equal = equal
      let hash t = t.hash
    end)
end

(**** Find a free index ****)

type working_area = bool array ref

let create_working_area () = ref [| false |]

let index_count w = Array.length !w

let reset_table a = Array.fill a 0 (Array.length a) false

let rec mark_used_indices tbl =
  List.iter (function
      | E.TSeq (l, _, _) -> mark_used_indices tbl l
      | E.TExp (marks, _)
      | E.TMatch marks ->
        List.iter (fun (_, i) -> if i >= 0 then tbl.(i) <- true)
          marks.Marks.marks)

let rec find_free tbl idx len =
  if idx = len || not tbl.(idx) then idx else find_free tbl (idx + 1) len

let free_index tbl_ref l =
  let tbl = !tbl_ref in
  reset_table tbl;
  mark_used_indices tbl l;
  let len = Array.length tbl in
  let idx = find_free tbl 0 len in
  if idx = len then tbl_ref := Array.make (2 * len) false;
  idx

(**** Computation of the next state ****)

let remove_matches = List.filter (function E.TMatch _ -> false | _ -> true)

let rec split_at_match_rec l' = function
  | []            -> assert false
  | E.TMatch _ :: r -> (List.rev l', remove_matches r)
  | x :: r        -> split_at_match_rec (x :: l') r

let split_at_match l = split_at_match_rec [] l

let rec remove_duplicates prev l y =
  match l with
    [] ->
    ([], prev)
  | E.TMatch _ as x :: _ -> (* Truncate after first match *)
    ([x], prev)
  | E.TSeq (l', x, kind) :: r ->
    let (l'', prev') = remove_duplicates prev l' x in
    let (r', prev'') = remove_duplicates prev' r y in
    (E.tseq kind l'' x r', prev'')
  | E.TExp (_marks, {def = Eps; _}) as e :: r ->
    if List.memq y.id prev then
      remove_duplicates prev r y
    else
      let (r', prev') = remove_duplicates (y.id :: prev) r y in
      (e :: r', prev')
  | E.TExp (_marks, x) as e :: r ->
    if List.memq x.id prev then
      remove_duplicates prev r y
    else
      let (r', prev') = remove_duplicates (x.id :: prev) r y in
      (e :: r', prev')

let rec set_idx idx = function
  | [] ->
    []
  | E.TMatch marks :: r ->
    E.TMatch (Marks.marks_set_idx marks idx) :: set_idx idx r
  | E.TSeq (l', x, kind) :: r ->
    E.TSeq (set_idx idx l', x, kind) :: set_idx idx r
  | E.TExp (marks, x) :: r ->
    E.TExp ((Marks.marks_set_idx marks idx), x) :: set_idx idx r

let filter_marks b e marks =
  {marks with Marks.marks = List.filter (fun (i, _) -> i < b || i > e) marks.Marks.marks }

let rec delta_1 marks c cat' cat x rem =
  (*Format.eprintf "%d@." x.id;*)
  match x.def with
    Cst s ->
    if Cset.mem c s then E.texp marks eps_expr :: rem else rem
  | Alt l ->
    delta_2 marks c cat' cat l rem
  | Seq (kind, y, z) ->
    let y' = delta_1 marks c cat' cat y [] in
    delta_seq c cat' cat kind y' z rem
  | Rep (rep_kind, kind, y) ->
    let y' = delta_1 marks c cat' cat y [] in
    let (y'', marks') =
      match
        first
          (function E.TMatch marks -> Some marks | _ -> None) y'
      with
        None        -> (y', marks)
      | Some marks' -> (remove_matches y', marks')
    in
    begin match rep_kind with
        `Greedy     -> E.tseq kind y'' x (E.TMatch marks' :: rem)
      | `Non_greedy -> E.TMatch marks :: E.tseq kind y'' x rem
    end
  | Eps ->
    E.TMatch marks :: rem
  | Mark i ->
    let marks = { marks with Marks.marks = (i, -1) :: List.remove_assq i marks.Marks.marks } in
    E.TMatch marks :: rem
  | Pmark i ->
    let marks = { marks with Marks.pmarks = PmarkSet.add i marks.Marks.pmarks } in
    E.TMatch marks :: rem
  | Erase (b, e) ->
    E.TMatch (filter_marks b e marks) :: rem
  | Before cat'' ->
    if cat land cat'' <> 0 then E.TMatch marks :: rem else rem
  | After cat'' ->
    if cat' land cat'' <> 0 then E.TMatch marks :: rem else rem

and delta_2 marks c cat' cat l rem =
  match l with
    []     -> rem
  | y :: r -> delta_1 marks c cat' cat y (delta_2 marks c cat' cat r rem)

and delta_seq c cat' cat kind y z rem =
  match
    first (function E.TMatch marks -> Some marks | _ -> None) y
  with
    None ->
    E.tseq kind y z rem
  | Some marks ->
    match kind with
      `Longest ->
      E.tseq kind (remove_matches y) z (delta_1 marks c cat' cat z rem)
    | `Shortest ->
      delta_1 marks c cat' cat z (E.tseq kind (remove_matches y) z rem)
    | `First ->
      let (y', y'') = split_at_match y in
      E.tseq kind y' z (delta_1 marks c cat' cat z (E.tseq kind y'' z rem))

let rec delta_3 c cat' cat x rem =
  match x with
    E.TSeq (y, z, kind) ->
    let y' = delta_4 c cat' cat y [] in
    delta_seq c cat' cat kind y' z rem
  | E.TExp (marks, e) ->
    delta_1 marks c cat' cat e rem
  | E.TMatch _ ->
    x :: rem

and delta_4 c cat' cat l rem =
  match l with
    []     -> rem
  | y :: r -> delta_3 c cat' cat y (delta_4 c cat' cat r rem)

let delta tbl_ref cat' char st =
  let (expr', _) =
    remove_duplicates [] (delta_4 char st.State.category cat' st.State.desc [])
      eps_expr in
  let idx = free_index tbl_ref expr' in
  let expr'' = set_idx idx expr' in
  State.mk idx cat' expr''

(****)

let rec red_tr = function
  | [] | [_] as l ->
    l
  | ((s1, st1) as tr1) :: ((s2, st2) as tr2) :: rem ->
    if State.equal st1 st2 then
      red_tr ((Cset.union s1 s2, st1) :: rem)
    else
      tr1 :: red_tr (tr2 :: rem)

let simpl_tr l =
  List.sort
    (fun (s1, _) (s2, _) -> compare s1 s2)
    (red_tr (List.sort (fun (_, st1) (_, st2) -> State.compare st1 st2) l))

(****)

let prepend_deriv = List.fold_right (fun (s, x) l -> Cset.prepend s x l)

let rec restrict s = function
  | [] -> []
  | (s', x') :: rem ->
    let s'' = Cset.inter s s' in
    if Cset.is_empty s''
    then restrict s rem
    else (s'', x') :: restrict s rem

let rec remove_marks b e rem =
  if b > e then rem else remove_marks b (e - 1) ((e, -2) :: rem)

let rec prepend_marks_expr m = function
  | E.TSeq (l, e', s) -> E.TSeq (prepend_marks_expr_lst m l, e', s)
  | E.TExp (m', e')   -> E.TExp (Marks.merge m m', e')
  | E.TMatch m'       -> E.TMatch (Marks.merge m m')

and prepend_marks_expr_lst m l =
  List.map (prepend_marks_expr m) l

let prepend_marks m =
  List.map (fun (s, x) -> (s, prepend_marks_expr_lst m x))

let rec deriv_1 all_chars categories marks cat x rem =
  match x.def with
  | Cst s ->
    Cset.prepend s [E.texp marks eps_expr] rem
  | Alt l ->
    deriv_2 all_chars categories marks cat l rem
  | Seq (kind, y, z) ->
    let y' = deriv_1 all_chars categories marks cat y [(all_chars, [])] in
    deriv_seq all_chars categories cat kind y' z rem
  | Rep (rep_kind, kind, y) ->
    let y' = deriv_1 all_chars categories marks cat y [(all_chars, [])] in
    List.fold_right
      (fun (s, z) rem ->
         let (z', marks') =
           match
             first
               (function E.TMatch marks -> Some marks | _ -> None)
               z
           with
             None        -> (z, marks)
           | Some marks' -> (remove_matches z, marks')
         in
         Cset.prepend s
           (match rep_kind with
              `Greedy     -> E.tseq kind z' x [E.TMatch marks']
            | `Non_greedy -> E.TMatch marks :: E.tseq kind z' x [])
           rem)
      y' rem
  | Eps ->
    Cset.prepend all_chars [E.TMatch marks] rem
  | Mark i ->
    Cset.prepend all_chars [E.TMatch {marks with Marks.marks = ((i, -1) :: List.remove_assq i marks.Marks.marks)}] rem
  | Pmark _ ->
    Cset.prepend all_chars [E.TMatch marks] rem
  | Erase (b, e) ->
    Cset.prepend all_chars
      [E.TMatch {marks with Marks.marks = (remove_marks b e (filter_marks b e marks).Marks.marks)}] rem
  | Before cat' ->
    Cset.prepend (List.assq cat' categories) [E.TMatch marks] rem
  | After cat' ->
    if cat land cat' <> 0 then Cset.prepend all_chars [E.TMatch marks] rem else rem

and deriv_2 all_chars categories marks cat l rem =
  match l with
    []     -> rem
  | y :: r -> deriv_1 all_chars categories marks cat y
                (deriv_2 all_chars categories marks cat r rem)

and deriv_seq all_chars categories cat kind y z rem =
  if
    List.exists
      (fun (_s, xl) ->
         List.exists (function E.TMatch _ -> true | _ -> false) xl)
      y
  then
    let z' = deriv_1 all_chars categories Marks.empty cat z [(all_chars, [])] in
    List.fold_right
      (fun (s, y) rem ->
         match
           first (function E.TMatch marks -> Some marks | _ -> None)
             y
         with
           None ->
           Cset.prepend s (E.tseq kind y z []) rem
         | Some marks ->
           let z'' = prepend_marks marks z' in
           match kind with
             `Longest ->
             Cset.prepend s (E.tseq kind (remove_matches y) z []) (
               prepend_deriv (restrict s z'') rem)
           | `Shortest ->
             prepend_deriv (restrict s z'') (
               Cset.prepend s (E.tseq kind (remove_matches y) z []) rem)
           | `First ->
             let (y', y'') = split_at_match y in
             Cset.prepend s (E.tseq kind y' z []) (
               prepend_deriv (restrict s z'') (
                 Cset.prepend s (E.tseq kind y'' z []) rem)))
      y rem
  else
    List.fold_right
      (fun (s, xl) rem -> Cset.prepend s (E.tseq kind xl z []) rem) y rem

let rec deriv_3 all_chars categories cat x rem =
  match x with
    E.TSeq (y, z, kind) ->
    let y' = deriv_4 all_chars categories cat y [(all_chars, [])] in
    deriv_seq all_chars categories cat kind y' z rem
  | E.TExp (marks, e) ->
    deriv_1 all_chars categories marks cat e rem
  | E.TMatch _ ->
    Cset.prepend all_chars [x] rem

and deriv_4 all_chars categories cat l rem =
  match l with
    []     -> rem
  | y :: r -> deriv_3 all_chars categories cat y
                (deriv_4 all_chars categories cat r rem)

let deriv tbl_ref all_chars categories st =
  let der = deriv_4 all_chars categories st.State.category st.State.desc
      [(all_chars, [])] in
  simpl_tr (
    List.fold_right (fun (s, expr) rem ->
        let (expr', _) = remove_duplicates [] expr eps_expr in
(*
Format.eprintf "@[<3>@[%a@]: %a / %a@]@." Cset.print s print_state expr print_state expr';
*)
        let idx = free_index tbl_ref expr' in
        let expr'' = set_idx idx expr' in
        List.fold_right (fun (cat', s') rem ->
            let s'' = Cset.inter s s' in
            if Cset.is_empty s''
            then rem
            else (s'', State.mk idx cat' expr'') :: rem)
          categories rem) der [])

(****)

let flatten_match m =
  let ma = List.fold_left (fun ma (i, _) -> max ma i) (-1) m in
  let res = Array.make (ma + 1) (-1) in
  List.iter (fun (i, v) -> res.(i) <- v) m;
  res

let status s =
  match s.State.status with
    Some st ->
    st
  | None ->
    let st =
      match s.State.desc with
        []              -> Failed
      | E.TMatch m :: _ -> Match (flatten_match m.Marks.marks, m.Marks.pmarks)
      | _               -> Running
    in
    s.State.status <- Some st;
    st
