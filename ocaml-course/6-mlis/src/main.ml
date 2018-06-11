open Core
open Async

let write writer diff = 
  let write x = 
    let%map () = Pipe.write writer x in
    printf "wrote %d %5.2f\n" x (diff ())
  in
  let%map () = 
    let%bind () = write 1 in
    let%bind () = write 2 in
    write 3
  and () =
    let%bind () = write 4 in
    let%bind () = write 5 in
    write 6
  in
  ()

let test_pushback () = 
  printf "\nstart test_pushback\n";
  let start = Time.now () in
  let diff () = Time.Span.to_sec (Time.diff (Time.now ()) start) in
  let reader, writer = Pipe.create () in
  let () = don't_wait_for begin
    Pipe.iter reader ~f:(fun x ->
      printf "read, waiting %d %5.2f\n" x (diff ());
      let%map () = Async.after (Time.Span.of_sec 0.5) in
      printf "read, waited %d %5.2f\n" x (diff ()))
  end
  in
  write writer diff

let test_without_pushback () = 
  printf "\nstart test_without_pushback\n";
  let start = Time.now () in
  let diff () = Time.Span.to_sec (Time.diff (Time.now ()) start) in
  let reader, writer = Pipe.create () in
  let () = don't_wait_for begin
    Pipe.iter_without_pushback reader ~f:(fun x ->
      printf "read, waiting %d %5.2f\n" x (diff ());
      don't_wait_for begin
        let%map () = Async.after (Time.Span.of_sec 0.5) in
        printf "read, waited %d %5.2f\n" x (diff ())
      end)
  end
  in
  write writer diff
;;

let test_multireader_naive () = 
  printf "\nstart test_multireader_naive\n";
  let start = Time.now () in
  let diff () = Time.Span.to_sec (Time.diff (Time.now ()) start) in
  let reader, writer = Linear_pipe.create () in
  let () = don't_wait_for begin
    Linear_pipe.iter reader ~f:(fun x ->
      printf "read1, waiting %d %5.2f\n" x (diff ());
      let%map () = Async.after (Time.Span.of_sec 0.5) in
      printf "read1, waited %d %5.2f\n" x (diff ()))
  end
  in
  let () = don't_wait_for begin
    Linear_pipe.iter reader ~f:(fun x ->
      printf "read2, waiting %d %5.2f\n" x (diff ());
      let%map () = Async.after (Time.Span.of_sec 0.5) in
      printf "read2, waited %d %5.2f\n" x (diff ()))
  end
  in
  write writer diff
;;

let test_multireader_transfer () = 
  printf "\nstart test_multireader_transfer\n";
  let start = Time.now () in
  let diff () = Time.Span.to_sec (Time.diff (Time.now ()) start) in
  let reader, writer = Pipe.create () in
  let readerA, writerA = Pipe.create () in
  let readerB, writerB = Pipe.create () in
  let () = don't_wait_for (Pipe.transfer reader writerA ~f:(fun x -> x)) in
  let () = don't_wait_for (Pipe.transfer reader writerB ~f:(fun x -> x)) in
  let () = don't_wait_for begin
    Pipe.iter readerA ~f:(fun x ->
      printf "read1, waiting %d %5.2f\n" x (diff ());
      let%map () = Async.after (Time.Span.of_sec 0.5) in
      printf "read1, waited %d %5.2f\n" x (diff ()))
  end
  in
  let () = don't_wait_for begin
    Pipe.iter readerB ~f:(fun x ->
      printf "read2, waiting %d %5.2f\n" x (diff ());
      let%map () = Async.after (Time.Span.of_sec 0.5) in
      printf "read2, waited %d %5.2f\n" x (diff ()))
  end
  in
  write writer diff
;;



(* TODO is possible to make "safe-reader"? That doesn't typecheck if more than one read type call could happen at once? *)

let test_multireader_fork () = 
  printf "\nstart test_multireader_fork\n";
  let start = Time.now () in
  let diff () = Time.Span.to_sec (Time.diff (Time.now ()) start) in
  let reader, writer = Linear_pipe.create () in
  let readerA, readerB = Linear_pipe.fork2 reader in
  let () = don't_wait_for begin
    Linear_pipe.iter readerA ~f:(fun x ->
      printf "read1, waiting %d %5.2f\n" x (diff ());
      let%map () = Async.after (Time.Span.of_sec 0.5) in
      printf "read1, waited %d %5.2f\n" x (diff ()))
  end
  in
  let () = don't_wait_for begin
    Linear_pipe.iter readerB ~f:(fun x ->
      printf "read2, waiting %d %5.2f\n" x (diff ());
      let%map () = Async.after (Time.Span.of_sec 0.5) in
      printf "read2, waited %d %5.2f\n" x (diff ()))
  end
  in
  write writer diff
;;

let%bind () = test_multireader_fork () in
(*let%bind () = test_pushback () in
let%bind () = Async.after (Time.Span.of_sec 1.0) in
let%bind () = test_without_pushback () in*)
return()
;;

let () = never_returns (Scheduler.go ())
;;
