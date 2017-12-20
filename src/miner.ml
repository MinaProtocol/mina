open Core_kernel
open Async_kernel

module type S = sig
  val mine
    : [ `Change_head of Block.t ] Pipe.Reader.t
    -> [ `Change_body of Block.Body.t ] Pipe.Reader.t
    -> Block.t Pipe.Reader.t Deferred.t
end

let mine (head : [`Change_head of Block.t]) (body : [`Change_body of Block.Body.t]) = 
  let%bind () = Async.after (Time.Span.of_sec 1.4) in
  return None
  (*return (Some (`Change_head head))*)

let replace_with_newest curr updates = 
  let newest = Pipe.read_now' updates in
  let next = 
    match newest with
    | `Eof | `Nothing_available -> None
    | `Ok newest -> Queue.fold newest ~init:None ~f:(fun x y -> Some y)
  in
  match next with
  | None -> curr
  | Some next -> next

module Cpu = struct
  let mine head_updates body_updates = 
    let mined_blocks_reader, mined_blocks_writer = Pipe.create () in
    let () = 
      don't_wait_for begin
        let rec go head body = 
          let%bind () = 
            match%bind mine head body with
            | None -> return ()
            | Some block -> Pipe.write mined_blocks_writer block
          in
          go (replace_with_newest head head_updates) (replace_with_newest body body_updates)
        in
        let%bind head = Pipe.read head_updates 
        and body = Pipe.read body_updates in
        match (head, body) with
        | (`Ok head, `Ok body) -> go head body
        | _ -> return ()
      end
    in
    return mined_blocks_reader
end
