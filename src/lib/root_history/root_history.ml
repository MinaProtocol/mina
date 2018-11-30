open Coda_numbers
open Core

type 'a t =
  { max_size: int
  ; queue: (Length.t * 'a) Doubly_linked.t
  ; by_length: (Length.t * 'a) Doubly_linked.Elt.t Length.Table.t }

let length_max x y = if Length.compare x y > 0 then x else y

let length_min x y = if Length.compare x y < 0 then x else y

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

let push t ~length ~data =
  let elt = Doubly_linked.insert_last t.queue (length, data) in
  Hashtbl.set t.by_length ~key:length ~data:elt ;
  remove_old_data length t

let find t length =
  Option.map (Hashtbl.find t.by_length length) ~f:(fun e ->
      snd (Doubly_linked.Elt.value e) )

let find_exn t length = Option.value_exn (find t length)

let create ~max_size =
  {max_size; queue= Doubly_linked.create (); by_length= Length.Table.create ()}
