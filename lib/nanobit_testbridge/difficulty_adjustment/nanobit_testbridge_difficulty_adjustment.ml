open Core
open Async
open Nanobit_base


let pattern n = 
  assert (n%4 = 0);
  [ `Kill 2
  ; `Start 1
  ; `Start 1
  ; `Kill (n/2)
  ; `Start (n/4)
  ; `Start (n/4)
  ; `Kill (n-1)
  ]
;;

let main nanobits = 
  printf "host started: %s\n" (Sexp.to_string_hum ([%sexp_of: Nanobit_testbridge.Nanobit.t list] nanobits));
  printf "initing nanobits...\n";
  let%bind args = Nanobit_testbridge.run_main_fully_connected nanobits ~should_mine:true in
  printf "init'd nanobits: %s\n" (Sexp.to_string_hum ([%sexp_of: Nanobit_testbridge.Rpcs.Main.query list] args));
  printf "starting test\n";

  let strengths = ref [] in
  let time_diffs = ref [] in

  let last_time = ref None in

  let update_difficulty blockchain = 
    let state = blockchain.Blockchain.state in
    let target = (Nanobit_base.Target.to_bigint state.Blockchain_state.target) in

    let time = state.Blockchain_state.previous_time in
    match !last_time with
    | None -> ()
    | Some previous_time -> begin
      let a = Block_time.to_time time in
      let b = Block_time.to_time previous_time in
      let time_diff = Time.Span.to_sec (Time.diff a b) in
      time_diffs := List.append !time_diffs [ time_diff ];
      if List.length !time_diffs > 16
      then time_diffs := List.drop !time_diffs 1
    end;
    last_time := Some time;

    let strength = Bignum.Bigint.((Nanobit_base.Target.to_bigint Nanobit_base.Target.max) / target) in
    strengths := List.append !strengths [ Bignum.Bigint.to_int_exn strength ];
    if List.length !strengths > 16
    then strengths := List.drop !strengths 1;

    let avg_time_diff = (List.reduce_exn !time_diffs ~f:(+.)) /. Int.to_float (List.length !time_diffs) in
    let avg_strength = (List.reduce_exn !strengths ~f:(+)) / (List.length !strengths) in
    printf "update strength: %d, avg time_diff: %f\n" avg_strength avg_time_diff
  in

  let check_difficulty alive_nodes =
    let%map () = after (sec 300.0) in
    let avg_time_diff = (List.reduce_exn !time_diffs ~f:(+.)) /. Int.to_float (List.length !time_diffs) in
    let avg_strength = (List.reduce_exn !strengths ~f:(+)) / (List.length !strengths) in
    let target_time_diff = 8.0 in
    let pass = Float.abs (avg_time_diff -. target_time_diff) < 1.0 in
    printf "check pass: %b, update strength: %d, avg time_diff: %f, alive nodes: %d \n" pass avg_strength avg_time_diff alive_nodes;
    assert pass
  in

  don't_wait_for begin
    Deferred.List.iteri ~how:`Parallel nanobits
      ~f:(fun i nanobit ->
        Deferred.ignore begin
          Nanobit_testbridge.get_strongest_blocks 
            nanobit
            ~f:(fun pipe -> 
              let%map () = 
                Pipe.iter_without_pushback pipe ~f:(fun blockchain -> 
                  update_difficulty blockchain
                )
              in
              Ok ()
            )
        end
      )
  end;

  let nanobits_state = Nanobit_testbridge.init_alive_dead_nanobits nanobits args in

  let%bind _ = 
    Deferred.List.fold
      ~init:nanobits_state
      (pattern (List.length nanobits)) ~f:(fun nanobits_state cmd ->
        match cmd with
        | `Kill n -> 
          printf "kill %d\n" n;
          let%bind nanobits_state = Nanobit_testbridge.kill_nanobits n nanobits_state in
          let%map () = check_difficulty (List.length (fst nanobits_state)) in
          nanobits_state
        | `Start n -> 
          printf "start %d\n" n;
          let%bind nanobits_state = Nanobit_testbridge.start_nanobits n nanobits_state in
          let%map () = check_difficulty (List.length (fst nanobits_state)) in
          nanobits_state
      )
  in

  printf "done\n";
  Async.never ()
;;

let () = Nanobit_testbridge.cmd main
;;

let () = never_returns (Scheduler.go ())
;;
