open Core
open Async
open Coda_worker
open Coda_main
open Signature_lib
open Coda_base
open Pipe_lib

module Api = struct
  type t =
    { workers: Coda_process.t list
    ; configs: Coda_worker.Input.t list
    ; start_writer:
        (int * Coda_worker.Input.t * (unit -> unit) * (unit -> unit))
        Linear_pipe.Writer.t
    ; status: [`On of [`Synced | `Catchup] | `Off] Array.t
    ; payment_writer: User_command.t Linear_pipe.Writer.t }

  let create configs workers payment_writer start_writer =
    let status = Array.init (List.length workers) ~f:(fun _ -> `On `Synced) in
    {workers; configs; start_writer; status; payment_writer}

  let online t i = match t.status.(i) with `On _ -> true | `Off -> false

  let synced t i =
    match t.status.(i) with
    | `On `Synced -> true
    | `On `Catchup -> false
    | `Off -> false

  let run_online_worker ~f ~arg t i =
    let worker = List.nth_exn t.workers i in
    if online t i then Deferred.map (f ~worker arg) ~f:(fun x -> Some x)
    else return None

  let get_balance t i pk =
    run_online_worker ~arg:pk
      ~f:(fun ~worker pk -> Coda_process.get_balance_exn worker pk)
      t i

  let get_nonce t i pk =
    run_online_worker ~arg:pk
      ~f:(fun ~worker pk -> Coda_process.get_nonce_exn worker pk)
      t i

  let start t i =
    Linear_pipe.write t.start_writer
      ( i
      , List.nth_exn t.configs i
      , (fun () -> t.status.(i) <- `On `Catchup)
      , fun () -> t.status.(i) <- `On `Synced )

  let stop t i =
    t.status.(i) <- `Off ;
    Coda_process.disconnect (List.nth_exn t.workers i)

  let send_payment t i sender_sk receiver_pk amount fee =
    let sender_pk =
      Public_key.of_private_key_exn sender_sk |> Public_key.compress
    in
    (let open Deferred.Option.Let_syntax in
    let%bind maybe_nonce = get_nonce t i sender_pk in
    let nonce = Option.value_exn maybe_nonce in
    let payload =
      User_command.Payload.create ~fee ~nonce ~memo:User_command_memo.dummy
        ~body:(Payment {receiver= receiver_pk; amount})
    in
    let cmd =
      User_command.sign (Keypair.of_private_key_exn sender_sk) payload
    in
    let%map _ =
      run_online_worker
        ~arg:(cmd :> User_command.t)
        ~f:(fun ~worker cmd -> Coda_process.process_payment_exn worker cmd)
        t i
    in
    Linear_pipe.write t.payment_writer (cmd :> User_command.t)
    |> don't_wait_for)
    |> ignore ;
    Deferred.unit

  let send_payment_with_receipt t i sk pk amount fee =
    run_online_worker ~arg:(sk, pk, amount, fee)
      ~f:(fun ~worker (sk, pk, amount, fee) ->
        Coda_process.send_payment_exn worker sk pk amount fee
          User_command_memo.dummy )
      t i

  (* TODO: resulting_receipt should be replaced with the sender's pk so that we prove the
      merkle_list of receipts up to the current state of a sender's receipt_chain hash for some blockchain.
      However, whenever we get a new transition, the blockchain does not update and `prove_receipt` would not query
      the merkle list that we are looking for *)
  let prove_receipt t i proving_receipt resulting_receipt =
    run_online_worker
      ~arg:(proving_receipt, resulting_receipt)
      ~f:(fun ~worker (proving_receipt, resulting_receipt) ->
        Coda_process.prove_receipt_exn worker proving_receipt resulting_receipt
        )
      t i

  let teardown t = Deferred.List.iter t.workers ~f:Coda_process.disconnect
end

let start_prefix_check log workers events testnet ~acceptable_delay =
  let all_transitions_r, all_transitions_w = Linear_pipe.create () in
  let chains = Array.init (List.length workers) ~f:(fun i -> []) in
  let check_chains chains =
    let chains = Array.filteri chains ~f:(fun i _ -> Api.synced testnet i) in
    let lengths =
      Array.to_list (Array.map chains ~f:(fun c -> List.length c))
    in
    let first = chains.(0) in
    let rest = Array.slice chains 1 0 in
    let newest_shared =
      List.find first ~f:(fun x ->
          Array.for_all rest ~f:(fun c -> List.exists c ~f:(fun y -> x = y)) )
    in
    let shared_idx =
      match newest_shared with
      | None -> List.length first
      | Some shared ->
          Option.value_exn
            (Option.map
               (List.findi first ~f:(fun _ x -> x = shared))
               ~f:(fun x -> fst x))
    in
    let shared_prefix_age = shared_idx in
    Logger.info log
      !"lengths: %{sexp: int list} shared_prefix: %{sexp: string option} \
        shared_prefix_age: %d"
      lengths newest_shared shared_prefix_age ;
    if not (shared_prefix_age <= 5) then (
      Logger.fatal log "prefix too old" ;
      ignore (exit 1) ) ;
    ()
  in
  let last_time = ref (Time.now ()) in
  don't_wait_for
    (let epsilon = 1.0 in
     let rec go () =
       let diff = Time.diff (Time.now ()) !last_time in
       let diff = Time.Span.to_sec diff in
       if
         not
           ( diff
           < Time.Span.to_sec acceptable_delay
             +. epsilon
             +. Int.to_float
                  ( (Consensus.Constants.c - 1)
                  * Consensus.Constants.block_window_duration_ms )
                /. 1000. )
       then (
         Logger.fatal log "no recent blocks" ;
         ignore (exit 1) ) ;
       let%bind () = after (Time.Span.of_sec 1.0) in
       go ()
     in
     go ()) ;
  don't_wait_for
    (Deferred.ignore
       (Linear_pipe.fold ~init:chains all_transitions_r
          ~f:(fun chains (prev, curr, i) ->
            let bits_to_str b =
              let str =
                String.concat (List.map b ~f:(fun x -> if x then "1" else "0"))
              in
              let hash = Md5.digest_string str in
              Md5.to_hex hash
            in
            let curr = bits_to_str curr in
            let chain = chains.(i) in
            let chain = curr :: chain in
            last_time := Time.now () ;
            chains.(i) <- chain ;
            check_chains chains ;
            return chains ))) ;
  don't_wait_for
    (Linear_pipe.iter events ~f:(function `Transition (i, (prev, curr)) ->
         Linear_pipe.write all_transitions_w (prev, curr, i) ))

let start_payment_check log best_tip_diff_pipe payment_pipe workers testnet
    ~acceptable_delay =
  let best_tip_lengths = Array.init (List.length workers) ~f:(Fn.const 0) in
  let active_user_commands = ref [] in
  let add_to_active_user_commands cmd =
    let snapshots =
      Array.init (List.length workers) ~f:(fun i ->
          if Api.synced testnet i then Some best_tip_lengths.(i) else None )
    in
    active_user_commands :=
      (snapshots, cmd, ref false) :: !active_user_commands
  in
  Linear_pipe.iter best_tip_diff_pipe ~f:(function
      | `Diff
          ( i
          , Protocols.Coda_transition_frontier.Best_tip_diff_view.({ new_user_commands
                                                                   ; removed_user_commands
                                                                   ; best_tip_length
                                                                   }) )
      ->
      best_tip_lengths.(i) <- best_tip_length ;
      List.iter !active_user_commands ~f:(function
          | snapshots, cmd, included_in_best_tip ->
          ( match snapshots.(i) with
          | None -> ()
          | Some best_tip_length_at_the_moment ->
              if
                best_tip_lengths.(i)
                <= best_tip_length_at_the_moment + acceptable_delay
              then (
                if List.mem new_user_commands cmd ~equal:User_command.equal
                then included_in_best_tip := true ;
                if List.mem removed_user_commands cmd ~equal:User_command.equal
                then included_in_best_tip := false )
              else if not @@ !included_in_best_tip then (
                Logger.fatal log
                  !"transaction took too long to get into the best tip of \
                    node %d"
                  i ;
                ignore (exit 1) ) ) ) ;
      Deferred.unit )
  |> don't_wait_for ;
  Linear_pipe.iter payment_pipe ~f:(function cmd ->
      add_to_active_user_commands cmd ;
      Deferred.unit )
  |> don't_wait_for

let events workers start_reader =
  let event_r, event_w = Linear_pipe.create () in
  let diff_r, diff_w = Linear_pipe.create () in
  let connect_worker i worker =
    let%bind transitions = Coda_process.strongest_ledgers_exn worker in
    let%bind diffs = Coda_process.best_tip_diff_exn worker in
    Linear_pipe.iter transitions ~f:(fun t ->
        Linear_pipe.write event_w (`Transition (i, t)) )
    |> don't_wait_for ;
    Linear_pipe.iter diffs ~f:(fun diff ->
        Linear_pipe.write diff_w (`Diff (i, diff)) )
  in
  don't_wait_for
    (Linear_pipe.iter start_reader ~f:(fun (i, config, started, synced) ->
         don't_wait_for
           (let%bind worker = Coda_process.spawn_exn config in
            started () ;
            don't_wait_for
              (let ms_to_catchup =
                 (Consensus.Constants.c + Consensus.Constants.delta)
                 * Consensus.Constants.block_window_duration_ms
                 + 16_000
                 |> Float.of_int
               in
               let%map () = after (Time.Span.of_ms ms_to_catchup) in
               synced ()) ;
            connect_worker i worker) ;
         Deferred.unit )) ;
  List.iteri workers ~f:(fun i w -> don't_wait_for (connect_worker i w)) ;
  (event_r, diff_r)

let start_checks log workers payment_reader start_reader testnet
    ~acceptable_delay =
  let event_pipe, diff_pipe = events workers start_reader in
  start_prefix_check log workers event_pipe testnet ~acceptable_delay ;
  start_payment_check log diff_pipe payment_reader workers testnet
    ~acceptable_delay:7

(* note: this is very declarative, maybe this should be more imperative? *)
(* next steps:
   *   add more powerful api hooks to enable sending payments on certain conditions
   *   implement stop/start
   *   change live whether nodes are producing, snark producing
   *   change network connectivity *)
let test log n proposers snark_work_public_keys work_selection =
  let log = Logger.child log "worker_testnet" in
  let proposal_interval = Consensus.Constants.block_window_duration_ms in
  let acceptable_delay =
    Time.Span.of_ms
      (proposal_interval * Consensus.Constants.delta |> Float.of_int)
  in
  let%bind program_dir = Unix.getcwd () in
  Coda_processes.init () ;
  let configs =
    Coda_processes.local_configs n ~proposal_interval ~program_dir ~proposers
      ~acceptable_delay
      ~snark_worker_public_keys:(Some (List.init n snark_work_public_keys))
      ~work_selection
      ~trace_dir:(Unix.getenv "CODA_TRACING")
  in
  let%map workers = Coda_processes.spawn_local_processes_exn configs in
  let payment_reader, payment_writer = Linear_pipe.create () in
  let start_reader, start_writer = Linear_pipe.create () in
  let testnet = Api.create configs workers payment_writer start_writer in
  start_checks log workers payment_reader start_reader testnet
    ~acceptable_delay ;
  testnet

module Payments : sig
  val send_several_payments :
       Api.t
    -> node:int
    -> src:Private_key.t
    -> dest:Public_key.Compressed.t
    -> unit Deferred.t
end = struct
  let send_several_payments testnet ~node ~src ~dest =
    let send_amount = Currency.Amount.of_int 10 in
    let fee = Currency.Fee.of_int 0 in
    let rec go i =
      let%bind () = after (Time.Span.of_sec 1.) in
      let%bind () = Api.send_payment testnet node src dest send_amount fee in
      if i > 0 then go (i - 1) else after (Time.Span.of_sec 1.)
      (* ensure a sleep at the end to let the last payment through *)
    in
    go 40
end

module Restarts : sig
  val restart_node :
       Api.t
    -> log:Logger.t
    -> node:int
    -> action:(unit -> unit Deferred.t)
    -> duration:Time.Span.t
    -> unit Deferred.t

  val trigger_catchup :
       Api.t
    -> log:Logger.t
    -> node:int
    -> largest_account_keypair:Keypair.t
    -> payment_receiver:int
    -> unit Deferred.t

  val trigger_bootstrap :
       Api.t
    -> log:Logger.t
    -> node:int
    -> largest_account_keypair:Keypair.t
    -> payment_receiver:int
    -> unit Deferred.t
end = struct
  let catchup_wait_duration =
    Time.Span.of_ms
    @@ ( (Consensus.Constants.c + Consensus.Constants.delta)
         * Consensus.Constants.block_window_duration_ms
       |> Float.of_int )

  let bootstrap_wait_duration =
    Time.Span.of_ms
    @@ ( Consensus.Constants.(c * ((2 * k) + delta) * block_window_duration_ms)
       |> Float.of_int )

  let restart_node testnet ~log ~node ~action ~duration =
    let%bind () = after (Time.Span.of_sec 5.) in
    Logger.info log "Stopping %d" node ;
    (* Send one payment *)
    let%bind () = Api.stop testnet node in
    let%bind () = action () in
    let%bind () = after duration in
    Api.start testnet node

  let restart_and_payment testnet ~node ~log ~largest_account_keypair ~duration
      ~payment_receiver =
    let sender_sk = largest_account_keypair.Keypair.private_key in
    let send_amount = Currency.Amount.of_int 10 in
    let fee = Currency.Fee.of_int 0 in
    let keypair = Keypair.create () in
    restart_node testnet ~node ~log
      ~action:(fun () ->
        Api.send_payment testnet payment_receiver sender_sk
          (Public_key.compress keypair.public_key)
          send_amount fee )
      ~duration

  let trigger_catchup testnet ~log ~node ~largest_account_keypair
      ~payment_receiver =
    Logger.info log "Triggering catchup on %d" node ;
    restart_and_payment testnet ~largest_account_keypair ~node ~log
      ~duration:catchup_wait_duration ~payment_receiver

  let trigger_bootstrap testnet ~log ~node ~largest_account_keypair
      ~payment_receiver =
    Logger.info log "Triggering bootstrap on %d" node ;
    restart_and_payment testnet ~largest_account_keypair ~node ~log
      ~duration:catchup_wait_duration ~payment_receiver
end
