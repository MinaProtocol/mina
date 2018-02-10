open Core

(* Invariants:
    - [to_pop] and [popped] are disjoint.
    - [to_pop] and [queue] have the same elements. *)
type 'a t =
  { queue  : 'a Doubly_linked.t
  ; to_pop : ('a, 'a Doubly_linked.Elt.t) Hashtbl.t
  ; popped : 'a Hash_set.t
  }

let invariant t =
  assert
    (Hashtbl.for_alli t.to_pop ~f:(fun ~key ~data:elt ->
        Doubly_linked.mem_elt t.queue elt
        && not (Hash_set.mem t.popped key)));
  Doubly_linked.iter_elt t.queue ~f:(fun elt ->
    assert
      (Doubly_linked.Elt.equal
        elt
        (Hashtbl.find_exn t.to_pop (Doubly_linked.Elt.value elt))));
;;

let create
  (type a)
  (h : (module Base.Hashtbl_intf.Key with type t = a))
  : a t
  =
  { queue = Doubly_linked.create ()
  ; popped = Hash_set.create h ()
  ; to_pop = Hashtbl.create h ()
  }

(* At some point it may make sense to make this O(1) instead
  of O(n) as it is now. *)
let add (t : 'a t) (x : 'a) =
  if not (Hash_set.mem t.popped x || Hashtbl.mem t.to_pop x)
  then begin
    let q = t.queue in
    let n = Doubly_linked.length q in
    (* There are n + 1 positions to insert into. *)
    let k = Random.int (n + 1) in
    let rec go i elt =
      if i = k
      then Doubly_linked.insert_before q elt x
      else
        match Doubly_linked.next q elt with
        | None -> Doubly_linked.insert_after q elt x
        | Some elt -> go (i + 1) elt
    in
    let elt =
      match Doubly_linked.first_elt q with
      | None -> Doubly_linked.insert_first q x
      | Some elt -> go 0 elt
    in
    Hashtbl.set t.to_pop ~key:x ~data:elt
  end
;;

let maybe_reshuffle t =
  if Doubly_linked.is_empty t.queue && not (Hash_set.is_empty t.popped)
  then begin
    assert (Hashtbl.is_empty t.to_pop);
    let xs = List.permute (Hash_set.to_list t.popped) in
    Hash_set.clear t.popped;
    List.iter xs ~f:(fun x ->
      let elt = Doubly_linked.insert_last t.queue x in
      Hashtbl.set t.to_pop ~key:x ~data:elt);
  end
;;

let remove t x =
  match Hashtbl.find_and_remove t.to_pop x with
  | None -> ()
  | Some elt ->
    Doubly_linked.remove t.queue elt;
    maybe_reshuffle t
;;

let pop t =
  match Doubly_linked.remove_first t.queue with
  | None -> None
  | Some x ->
    Hashtbl.remove t.to_pop x;
    Hash_set.add t.popped x;
    maybe_reshuffle t;
    Some x
;;

let to_list t = Hashtbl.keys t.to_pop @ Hash_set.to_list t.popped

let%test_unit "invariant" =
  let n = 10 in
  let t = create (module Int) in
  let xs = List.init n ~f:Fn.id in
  List.iter xs ~f:(fun i -> add t i);
  invariant t;
  begin
    Fn.apply_n_times ~n:(n / 2) (fun () ->
      assert (Option.is_some (pop t))) ();
    invariant t;
    Fn.apply_n_times ~n (fun () ->
      assert (Option.is_some (pop t))) ();
    invariant t;
    Fn.apply_n_times ~n:(n / 2) (fun () ->
      assert (Option.is_some (pop t))) ();
    invariant t;
  end;
  begin
    let ys = List.init n ~f:(fun _ -> Option.value_exn (pop t)) in
    invariant t;
    let xs = Int.Set.of_list xs in
    assert (Set.equal xs (Int.Set.of_list ys));
  end;
  begin
    let pt = 0 in
    remove t pt;
    invariant t;
    let ys = List.init (n - 1) ~f:(fun _ -> Option.value_exn (pop t)) in
    assert (Set.equal (Set.remove (Int.Set.of_list xs) pt) (Int.Set.of_list ys));
  end
;;
