open Core_kernel
open Async_kernel

module Writer = Pipe.Writer

module Reader = struct
  type 'a t =
    { pipe : 'a Pipe.Reader.t
    ; mutable has_reader : bool 
    }
end

let create () = 
  let r, w = Pipe.create () in
  ({ Reader.pipe = r; has_reader = false }, w)

let wrap_reader reader = { Reader.pipe = reader; has_reader = false }
;;

let close_read (reader : 'a Reader.t) = Pipe.close_read reader.pipe

let closed (reader : 'a Reader.t) = Pipe.closed reader.pipe

let bracket (reader : 'a Reader.t) dx =
  if reader.has_reader
  then failwith "Linear_pipe.bracket: had reader"
  else begin
    reader.has_reader <- true;
    let%map x = dx in
    reader.has_reader <- false;
    x
  end
;;

let set_reader_sync (reader : 'a Reader.t) =
  if reader.has_reader
  then failwith "Linear_pipe.bracket: had reader"
  else 
    reader.has_reader <- true;
    ()

let iter ?consumer ?continue_on_error reader ~f =
  bracket reader 
    (Pipe.iter 
      reader.Reader.pipe 
      ?consumer ?continue_on_error ~f)
;;

let of_list xs = 
  let reader = wrap_reader (Pipe.of_list xs) in
  set_reader_sync reader;
  reader
;;

let fold reader ~init ~f =
  set_reader_sync reader;
  Pipe.fold reader.Reader.pipe ~init ~f

let map (reader : 'a Reader.t) ~f = 
  set_reader_sync reader;
  let r = Pipe.map reader.Reader.pipe ~f in
  wrap_reader r
;;

let filter_map (reader : 'a Reader.t) ~f = 
  set_reader_sync reader;
  let r = Pipe.filter_map reader.Reader.pipe ~f in
  wrap_reader r
;;

let transfer reader writer ~f = 
  bracket reader (Pipe.transfer reader.Reader.pipe writer ~f)
;;

let merge rs = 
  let mergedReader, merged_writer = create () in
  ignore (List.map rs ~f:(fun reader -> 
    set_reader_sync reader;
    don't_wait_for (iter reader ~f:(fun x -> 
      Pipe.write merged_writer x))
  ));
  don't_wait_for begin
    let%map () = Deferred.all_ignore (List.map rs ~f:closed) in
    Pipe.close merged_writer
  end;
  mergedReader
;;

(* TODO following are all efficient with iter', 
 * but I get write' doesn't exist on my version of ocaml *)

let fork reader n = 
  let pipes = List.map (List.range 0 n) ~f:(fun _ -> create ()) in
  let writers = List.map pipes ~f:(fun (r, w) -> w) in
  let readers = List.map pipes ~f:(fun (r, w) -> r) in
  don't_wait_for begin
    iter reader ~f:(fun x -> 
      Deferred.all_ignore (List.map writers ~f:(fun writer -> 
        if not (Pipe.is_closed writer) 
        then Pipe.write writer x
        else return ())))
  end;
  don't_wait_for begin
    let%map () = Deferred.all_ignore (List.map readers ~f:closed) in
    close_read reader
  end;
  readers
;;

let fork2 reader = 
  let rs = fork reader 2 in
  (List.nth_exn rs 0, List.nth_exn rs 1)
;;

let fork3 reader = 
  let rs = fork reader 3 in
  (List.nth_exn rs 0, List.nth_exn rs 1, List.nth_exn rs 2)
;;

let partition_map2 reader ~f =
  let ((readerA, writerA), (readerB, writerB)) = (create (), create ()) in
  don't_wait_for begin
    iter reader ~f:(fun x ->
      match f x with
      | `Fst x -> Pipe.write writerA x
      | `Snd x -> Pipe.write writerB x)
  end;
  don't_wait_for begin
    let%map () = closed readerA 
    and () = closed readerB in
    close_read reader
  end;
  (readerA, readerB)

let partition_map3 reader ~f =
  let ((readerA, writerA), (readerB, writerB), (readerC, writerC)) = (create (), create (), create ()) in
  don't_wait_for begin
    iter reader ~f:(fun x -> 
      match f x with
      | `Fst x -> Pipe.write writerA x
      | `Snd x -> Pipe.write writerB x
      | `Trd x -> Pipe.write writerC x)
  end;
  don't_wait_for begin
    let%map () = closed readerA 
    and () = closed readerB 
    and () = closed readerC in
    close_read reader
  end;
  (readerA, readerB, readerC)


let filter_map_unordered t ~f =
  let reader, writer = create () in
  don't_wait_for begin
    iter t ~f:(fun x ->
      don't_wait_for begin
        match%map f x with
        | Some y -> Pipe.write_without_pushback writer y
        | None -> ()
      end;
      return ())
  end;
  don't_wait_for begin
    let%map () = closed reader in
    close_read t
  end;
  reader
;;
