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

let write_or_drop ~capacity writer reader x = 
  if Pipe.length reader.Reader.pipe > capacity
  then ignore (Pipe.read_now reader.Reader.pipe);
  Pipe.write_without_pushback writer x

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
       (List.init max_concurrency ~f:(fun _ -> run_reader ())))
;;

let length reader =
  Pipe.length reader.Reader.pipe
;;

let of_list xs = 
  let reader = wrap_reader (Pipe.of_list xs) in
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

let merge_unordered rs = 
   let merged_reader, merged_writer = create () in
   List.iter rs ~f:(fun reader -> 
     don't_wait_for (iter reader ~f:(fun x -> 
       Pipe.write merged_writer x))
   );
   don't_wait_for begin
     let%map () = Deferred.List.iter rs ~f:closed in
     Pipe.close merged_writer
   end;
   merged_reader
 ;;

(* TODO following are all more efficient with iter', 
 * but I get write' doesn't exist on my version of ocaml *)

let fork reader n = 
  let pipes = List.init n ~f:(fun _ -> create ()) in
  let writers = List.map pipes ~f:(fun (r, w) -> w) in
  let readers = List.map pipes ~f:(fun (r, w) -> r) in
  don't_wait_for begin
    iter reader ~f:(fun x -> 
      Deferred.List.iter writers ~f:(fun writer -> 
        if not (Pipe.is_closed writer) 
        then Pipe.write writer x
        else return ()))
  end;
  don't_wait_for begin
    let%map () = Deferred.List.iter readers ~f:closed in
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

let fork4 reader = 
  match fork reader 4 with
  | [x; y; z; w] -> (x, y, z, w)
  | _ -> assert false
;;

let fork5 reader = 
  match fork reader 5 with
  | [x; y; z; w; v] -> (x, y, z, w, v)
  | _ -> assert false
;;

let fork6 reader = 
  match fork reader 6 with
  | [x; y; z; w; v; u] -> (x, y, z, w, v, u)
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

let latest_ref t ~initial =
  let cell = ref initial in
  don't_wait_for begin
    iter t ~f:(fun a -> return (cell := a))
  end;
  cell
