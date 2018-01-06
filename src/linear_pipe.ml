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

let set_has_reader (reader : 'a Reader.t) =
  if reader.has_reader
  then failwith "Linear_pipe.bracket: had reader"
  else reader.has_reader <- true

let iter ?consumer ?continue_on_error reader ~f =
  bracket reader 
    (Pipe.iter 
      reader.Reader.pipe 
      ?consumer ?continue_on_error ~f)
;;

let iter_unordered ?consumer ~max_concurrency reader ~f =
  bracket reader 
    (let rec run_reader () =
       match%bind Pipe.read ?consumer reader.Reader.pipe with
       | `Eof -> return ()
       | `Ok v -> 
         let%bind () = f v in
         run_reader ()
     in
     Deferred.all_unit 
       (List.map (List.range 0 max_concurrency) ~f:(fun _ -> run_reader ())))
;;

let of_list xs = 
  let reader = wrap_reader (Pipe.of_list xs) in
  set_has_reader reader;
  reader
;;

let fold reader ~init ~f =
  bracket 
    reader
    (Pipe.fold reader.Reader.pipe ~init ~f)

let map (reader : 'a Reader.t) ~f = 
  set_has_reader reader;
  wrap_reader (Pipe.map reader.Reader.pipe ~f)
;;

let filter_map (reader : 'a Reader.t) ~f = 
  set_has_reader reader;
  wrap_reader (Pipe.filter_map reader.Reader.pipe ~f)
;;

let transfer reader writer ~f = 
  bracket reader (Pipe.transfer reader.Reader.pipe writer ~f)
;;

(* TODO ensure cmp doesn't cause readers to be blocked *)
let merge rs = 
  List.iter rs ~f:(fun reader -> set_has_reader reader);
  let readers = List.map rs ~f:(fun r -> r.pipe) in
  let merged_reader = wrap_reader (Pipe.merge readers (fun _ _ -> 1)) in
  don't_wait_for begin
    let%map () = Deferred.all_ignore (List.map rs ~f:closed) in
    Pipe.close_read merged_reader.pipe
  end;
  merged_reader
;;

(* TODO following are all efficient with iter', 
 * but I get write' doesn't exist on my version of ocaml *)

let fork reader n = 
  let pipes = List.init n ~f:(fun _ -> create ()) in
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
  match fork reader 2 with
  | [x; y] -> (x, y)
  | _ -> assert false
;;

let fork3 reader = 
  match fork reader 3 with
  | [x; y; z] -> (x, y, z)
  | _ -> assert false
;;

let partition_map2 reader ~f =
  let ((reader_a, writer_a), (reader_b, writer_b)) = (create (), create ()) in
  don't_wait_for begin
    iter reader ~f:(fun x ->
      match f x with
      | `Fst x -> Pipe.write writer_a x
      | `Snd x -> Pipe.write writer_b x)
  end;
  don't_wait_for begin
    let%map () = closed reader_a
    and () = closed reader_b in
    close_read reader
  end;
  (reader_a, reader_b)

let partition_map3 reader ~f =
  let ((reader_a, writer_a), (reader_b, writer_b), (reader_c, writer_c)) = (create (), create (), create ()) in
  don't_wait_for begin
    iter reader ~f:(fun x -> 
      match f x with
      | `Fst x -> Pipe.write writer_a x
      | `Snd x -> Pipe.write writer_b x
      | `Trd x -> Pipe.write writer_c x)
  end;
  don't_wait_for begin
    let%map () = closed reader_a 
    and () = closed reader_b 
    and () = closed reader_c in
    close_read reader
  end;
  (reader_a, reader_b, reader_c)


let filter_map_unordered ~max_concurrency t ~f =
  let reader, writer = create () in
  don't_wait_for begin
    iter_unordered ~max_concurrency t ~f:(fun x ->
      match%bind f x with
      | Some y -> Pipe.write writer y
      | None -> return ())
  end;
  don't_wait_for begin
    let%map () = closed reader in
    close_read t
  end;
  reader
;;
