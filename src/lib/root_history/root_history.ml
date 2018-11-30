open Coda_numbers
open Core

type 'a t =
  { max_size: int
  ; queue: (Length.t * 'a) Doubly_linked.t
  ; by_length: (Length.t * 'a) Doubly_linked.Elt.t Length.Table.t }

let remove_old_data newest t =
  let rec go () =
    match Doubly_linked.first t.queue with
    | None -> ()
    | Some (l, _) ->
        if Length.to_int newest - Length.to_int l > t.max_size then (
          Doubly_linked.remove_first t.queue |> ignore ;
          Hashtbl.remove t.by_length l ;
          go () )
  in
  go ()

let push_exn t ~length ~data =
  Option.iter (Doubly_linked.last t.queue) ~f:(fun (l, _) ->
      assert (Length.( < ) l length) ) ;
  let elt = Doubly_linked.insert_last t.queue (length, data) in
  Hashtbl.set t.by_length ~key:length ~data:elt ;
  remove_old_data length t

let push t ~length ~data =
  match push_exn t ~length ~data with
  | exception _ -> `Length_did_not_increase
  | () -> `Ok

let find t length =
  Option.map (Hashtbl.find t.by_length length) ~f:(fun e ->
      snd (Doubly_linked.Elt.value e) )

let find_exn t length = Option.value_exn (find t length)

let create ~max_size =
  {max_size; queue= Doubly_linked.create (); by_length= Length.Table.create ()}

let%test_unit "max_size invariant" =
  let open Quickcheck in
  let pushes =
    let open Generator in
    let open Let_syntax in
    let rec go n acc prev =
      if n = 0 then return (List.rev (prev :: acc))
      else
        let%bind k = small_positive_int in
        let prev' = Fn.apply_n_times ~n:k Length.succ prev in
        go (n - 1) (prev :: acc) prev'
    in
    let%bind n = small_positive_int in
    go n [] Coda_numbers.Length.zero
  in
  test
    Generator.(tuple2 small_positive_int pushes)
    ~f:(fun (max_size, ps) ->
      let t = create ~max_size in
      List.iter ps ~f:(fun length -> push_exn t ~length ~data:()) ;
      match
        Option.both (Doubly_linked.last t.queue) (Doubly_linked.first t.queue)
      with
      | None -> ()
      | Some ((oldest, _), (newest, _)) ->
          assert (Length.to_int newest - Length.to_int oldest <= max_size) )
