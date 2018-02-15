open Core
open Async
open Nanobit_base

let main nanobits = 
  printf "host started: %s\n" (Sexp.to_string_hum ([%sexp_of: Nanobit_testbridge.Nanobit.t list] nanobits));
  printf "initing nanobits...\n";
  let%bind args = Nanobit_testbridge.run_main_fully_connected nanobits ~should_mine:true in
  printf "init'd nanobits: %s\n" (Sexp.to_string_hum ([%sexp_of: Nanobit_testbridge.Rpcs.Main.query list] args));
  printf "starting test\n";

  let sca_length = ref 0 in

  don't_wait_for begin
    let rec go last_sca_length = 
      let%bind () = after (sec 30.) in
      let pass = !sca_length > last_sca_length in
      let () = 
        if not pass
        then printf "no new block in 30 seconds";
      in
      assert pass;
      go !sca_length
    in
    go !sca_length
  end;

  let check_sca chains = 
    let shortest = 
      Option.value_exn (
        List.min_elt (List.map chains ~f:(fun c -> List.length c)) Int.compare 
      ) 
    in
    if shortest = 0
    then ()
    else 
      let longest = 
        Option.value_exn (
          List.max_elt (List.map chains ~f:(fun c -> List.length c)) Int.compare 
        ) 
      in
      let hashes = List.init shortest ~f:(fun i -> List.map chains ~f:(fun chain -> List.nth_exn chain i)) in
      let matching_hashes = 
        List.map hashes 
          ~f:(fun hashes -> 
            List.for_all hashes 
              ~f:(fun hash -> 
                let a = Snark_params.Tick.Pedersen.Digest.Bits.to_bits hash in
                let b = Snark_params.Tick.Pedersen.Digest.Bits.to_bits (List.nth_exn hashes 0) in 
                List.equal a b Bool.equal)
          ) 
      in
      List.iter matching_hashes ~f:(fun h -> printf "%b, " h);
      let newest_match = 
        Option.value_exn (
          List.max_elt (
            List.mapi matching_hashes ~f:(fun i matches -> if matches then i else 0)
          ) Int.compare
        )
      in
      let ancestor_age = longest - newest_match in
      let pass = ancestor_age < 5 in
      sca_length := newest_match;
      printf "got blockchain %d %b\n" ancestor_age pass;
      assert pass
  in

  let update_chain states nanobit i hash number =
    printf "got blockchain %s %s %s\n"
      (Sexp.to_string_hum ([%sexp_of: Host_and_port.t] nanobit.Nanobit_testbridge.Nanobit.swim_addr))
      (Sexp.to_string_hum ([%sexp_of: Int64.t] number))
      (Sexp.to_string_hum ([%sexp_of: Snark_params.Tick.Pedersen.Digest.t] hash));
    let chain = List.nth_exn states i in
    chain := List.append !chain [ hash ];
    check_sca (List.map states ~f:(fun c -> !c))
  in

  don't_wait_for begin
    let states = List.init (List.length nanobits) ~f:(fun n -> ref []) in
    Deferred.List.iteri ~how:`Parallel nanobits
      ~f:(fun i nanobit ->
        Deferred.ignore begin
          Nanobit_testbridge.get_strongest_blocks 
            nanobit
            ~f:(fun pipe -> 
              let%map () = 
                Pipe.iter_without_pushback pipe ~f:(fun blockchain -> 
                  let blockchain_state = blockchain.Blockchain.state in
                  let number = blockchain_state.number in
                  let hash = blockchain_state.Blockchain_state.block_hash in
                  update_chain states nanobit i hash number
                )
              in
              Ok ()
            )
        end
      )
  end;

  printf "done\n";
  Async.never ()
;;

let () = Nanobit_testbridge.cmd main
;;

let () = never_returns (Scheduler.go ())
;;
