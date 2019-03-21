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
    ; payment_writer: (User_command.t * unit Ivar.t) Linear_pipe.Writer.t }

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
    let open Deferred.Option.Let_syntax in
    let worker = List.nth_exn t.workers i in
    let sender_pk =
      Public_key.of_private_key_exn sender_sk |> Public_key.compress
    in
    let%bind nonce = Coda_process.get_nonce_exn worker sender_pk in
    let payload =
      User_command.Payload.create ~fee ~nonce ~memo:User_command_memo.dummy
        ~body:(Payment {receiver= receiver_pk; amount})
    in
    let user_cmd =
      ( User_command.sign (Keypair.of_private_key_exn sender_sk) payload
        :> User_command.t )
    in
    let%map receipt =
      Coda_process.process_payment_exn worker user_cmd
      |> Deferred.map ~f:Or_error.ok
    in
    let result = Ivar.create () in
    Linear_pipe.write t.payment_writer (user_cmd, result) |> don't_wait_for ;
    (receipt, result)

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

module Tree = struct
  type key = string

  type t = {parent_map: (key, key) Hashtbl.t}

  let add t ~prev ~curr = Hashtbl.add t.parent_map ~key:curr ~data:prev

  let create () = {parent_map= Hashtbl.create (module String)}

  let path_from t node =
    let rec go acc cur =
      match Hashtbl.find t.parent_map cur with
      | Some parent -> go (parent :: acc) parent
      | None -> List.rev acc
    in
    go [] node
end

let start_prefix_check logger workers events testnet ~acceptable_delay =
  let all_transitions_r, all_transitions_w = Linear_pipe.create () in
  let state_hash_tree = Tree.create () in
  let chains = Array.init (List.length workers) ~f:(fun i -> "") in
  let check_chains chains =
    let chains = Array.filteri chains ~f:(fun i _ -> Api.synced testnet i) in
    let chains = Array.map chains ~f:(Tree.path_from state_hash_tree) in
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
    Logger.info logger ~module_:__MODULE__ ~location:__LOC__
      !"lengths: %{sexp: int list} shared_prefix: %{sexp: string option} \
        shared_prefix_age: %d"
      lengths newest_shared shared_prefix_age ;
    if not (shared_prefix_age <= 5) then (
      Logger.fatal logger ~module_:__MODULE__ ~location:__LOC__
        "prefix too old" ;
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
         Logger.fatal logger ~module_:__MODULE__ ~location:__LOC__
           "no recent blocks" ;
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
            let prev = bits_to_str prev in
            Tree.add state_hash_tree ~prev ~curr |> ignore ;
            last_time := Time.now () ;
            chains.(i) <- curr ;
            check_chains chains ;
            return chains ))) ;
  don't_wait_for
    (Linear_pipe.iter events ~f:(function `Transition (i, (prev, curr)) ->
         Linear_pipe.write all_transitions_w (prev, curr, i) ))

type user_cmd_status =
  {snapshots: int option array; passed_root: bool array; result: unit Ivar.t}

let start_payment_check logger root_pipe payment_pipe workers testnet
    ~acceptable_delay =
  let root_lengths = Array.init (List.length workers) ~f:(Fn.const 0) in
  let user_commands_under_inspection = Hashtbl.create (module User_command) in
  let add_to_user_commands_under_inspection (user_cmd, result) =
    let snapshots =
      Array.init (List.length workers) ~f:(fun i ->
          if Api.synced testnet i then Some root_lengths.(i) else None )
    in
    Logger.debug logger ~module_:__MODULE__ ~location:__LOC__
      !"user command %{sexp:User_command.t} is added and snapshots are \
        %{sexp:int option Array.t}"
      user_cmd snapshots ;
    Hashtbl.add user_commands_under_inspection ~key:user_cmd
      ~data:
        {snapshots; passed_root= Array.map snapshots ~f:Option.is_none; result}
    |> ignore
  in
  Linear_pipe.iter root_pipe ~f:(function
      | `Root
          ( i
          , Protocols.Coda_transition_frontier.Root_diff_view.({ user_commands
                                                               ; root_length })
          )
      ->
      Option.iter root_length ~f:(fun l -> root_lengths.(i) <- l) ;
      Logger.info logger ~module_:__MODULE__ ~location:__LOC__
        !"root length %{sexp:int option}, transactions %{sexp: User_command.t \
          list} for node %d"
        root_length user_commands i ;
      let user_commands_pass_inspection =
        Hashtbl.fold user_commands_under_inspection ~init:[]
          ~f:(fun ~key:user_cmd
             ~data:{snapshots; passed_root; _}
             user_commands_pass_inspection
             ->
            match snapshots.(i) with
            | None -> user_commands_pass_inspection
            | Some root_length_when_send_payment ->
                if passed_root.(i) then user_commands_pass_inspection
                else if
                  root_lengths.(i)
                  <= root_length_when_send_payment + Consensus.Constants.k
                     + acceptable_delay
                then
                  if List.mem user_commands user_cmd ~equal:User_command.equal
                  then (
                    passed_root.(i) <- true ;
                    Logger.info logger ~module_:__MODULE__ ~location:__LOC__
                      !"transaction %{sexp:User_command.t} finally gets into \
                        the root of node %d, when root length is %d"
                      user_cmd i root_lengths.(i) ;
                    if Array.for_all passed_root ~f:Fn.id then
                      user_cmd :: user_commands_pass_inspection
                    else user_commands_pass_inspection )
                  else user_commands_pass_inspection
                else (
                  Logger.fatal logger ~module_:__MODULE__ ~location:__LOC__
                    !"transaction %{sexp:User_command.t} took too long to get \
                      into the root of node %d"
                    user_cmd i ;
                  exit 1 |> don't_wait_for ;
                  user_commands_pass_inspection ) )
      in
      List.iter user_commands_pass_inspection ~f:(fun user_cmd ->
          let {result; _} =
            Hashtbl.find_exn user_commands_under_inspection user_cmd
          in
          Logger.info logger ~module_:__MODULE__ ~location:__LOC__
            !"transaction %{sexp:User_command.t} is included in the root for \
              all workers"
            user_cmd ;
          Ivar.fill result () ;
          Hashtbl.remove user_commands_under_inspection user_cmd )
      |> Deferred.return )
  |> don't_wait_for ;
  Linear_pipe.iter payment_pipe ~f:(fun (user_cmd, result) ->
      add_to_user_commands_under_inspection (user_cmd, result)
      |> Deferred.return )
  |> don't_wait_for

let events workers start_reader =
  let event_r, event_w = Linear_pipe.create () in
  let root_r, root_w = Linear_pipe.create () in
  let connect_worker i worker =
    let%bind transitions = Coda_process.strongest_ledgers_exn worker in
    let%bind roots = Coda_process.root_diff_exn worker in
    Linear_pipe.transfer transitions event_w ~f:(fun t -> `Transition (i, t))
    |> don't_wait_for ;
    Linear_pipe.transfer roots root_w ~f:(fun r -> `Root (i, r))
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
  (event_r, root_r)

let start_checks logger workers payment_reader start_reader testnet
    ~acceptable_delay =
  let event_reader, root_reader = events workers start_reader in
  start_prefix_check logger workers event_reader testnet ~acceptable_delay ;
  start_payment_check logger root_reader payment_reader workers testnet
    ~acceptable_delay:7

(* note: this is very declarative, maybe this should be more imperative? *)
(* next steps:
   *   add more powerful api hooks to enable sending payments on certain conditions
   *   implement stop/start
   *   change live whether nodes are producing, snark producing
   *   change network connectivity *)
let test logger n proposers snark_work_public_keys work_selection =
  let logger = Logger.extend logger [("worker_testnet", `Bool true)] in
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
  start_checks logger workers payment_reader start_reader testnet
    ~acceptable_delay ;
  testnet

module Payments : sig
  val send_several_payments :
       Api.t
    -> node:int
    -> sender_sk:Private_key.t
    -> receiver_pk:Public_key.Compressed.t
    -> (Receipt.Chain_hash.t * unit Ivar.t) list Option.t Deferred.t
end = struct
  let send_several_payments (t : Api.t) ~node:i ~sender_sk ~receiver_pk =
    let open Deferred.Option.Let_syntax in
    let worker = List.nth_exn t.workers i in
    let sender_pk =
      Public_key.of_private_key_exn sender_sk |> Public_key.compress
    in
    let%bind nonce0 = Coda_process.get_nonce_exn worker sender_pk in
    let nonces =
      List.(
        rev @@ snd
        @@ fold (init 40 ~f:Fn.id) ~init:(nonce0, [])
             ~f:(fun (nonce, nonces) _ ->
               (Account.Nonce.succ nonce, nonce :: nonces) ))
    in
    let amount = Currency.Amount.of_int 10 in
    let fee = Currency.Fee.of_int 0 in
    let payloads =
      List.map nonces ~f:(fun nonce ->
          User_command.Payload.create ~fee ~nonce ~memo:User_command_memo.dummy
            ~body:(Payment {receiver= receiver_pk; amount}) )
    in
    let user_cmds =
      List.map payloads ~f:(fun payload ->
          ( User_command.sign (Keypair.of_private_key_exn sender_sk) payload
            :> User_command.t ) )
    in
    let%map receipts_and_results =
      let open Deferred.Or_error in
      List.fold user_cmds ~init:[] ~f:(fun receipts_and_results user_cmd ->
          after (Time.Span.of_sec 15.)
          |> Deferred.map ~f:Or_error.return
          >>= fun () ->
          Coda_process.process_payment_exn worker user_cmd
          >>= fun receipt ->
          let result = Ivar.create () in
          Linear_pipe.write t.payment_writer (user_cmd, result)
          |> don't_wait_for ;
          return @@ Core.List.append receipts_and_results [(receipt, result)]
      )
      |> Deferred.map ~f:Or_error.ok
    in
    receipts_and_results
end

module Restarts : sig
  val restart_node :
       Api.t
    -> logger:Logger.t
    -> node:int
    -> action:(unit -> 'a Deferred.t)
    -> duration:Time.Span.t
    -> unit Deferred.t

  val trigger_catchup :
       Api.t
    -> logger:Logger.t
    -> node:int
    -> largest_account_keypair:Keypair.t
    -> payment_receiver:int
    -> unit Deferred.t

  val trigger_bootstrap :
       Api.t
    -> logger:Logger.t
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

  let restart_node testnet ~logger ~node ~action ~duration =
    let%bind () = after (Time.Span.of_sec 5.) in
    Logger.info logger ~module_:__MODULE__ ~location:__LOC__ "Stopping %d" node ;
    (* Send one payment *)
    let%bind () = Api.stop testnet node in
    let%bind _ = action () in
    let%bind () = after duration in
    Api.start testnet node

  let restart_and_payment testnet ~node ~logger ~largest_account_keypair
      ~duration ~payment_receiver =
    let sender_sk = largest_account_keypair.Keypair.private_key in
    let send_amount = Currency.Amount.of_int 10 in
    let fee = Currency.Fee.of_int 0 in
    let keypair = Keypair.create () in
    restart_node testnet ~node ~logger
      ~action:(fun () ->
        Api.send_payment testnet payment_receiver sender_sk
          (Public_key.compress keypair.public_key)
          send_amount fee )
      ~duration

  let trigger_catchup testnet ~logger ~node ~largest_account_keypair
      ~payment_receiver =
    Logger.info logger ~module_:__MODULE__ ~location:__LOC__
      "Triggering catchup on %d" node ;
    restart_and_payment testnet ~largest_account_keypair ~node ~logger
      ~duration:catchup_wait_duration ~payment_receiver

  let trigger_bootstrap testnet ~logger ~node ~largest_account_keypair
      ~payment_receiver =
    Logger.info logger ~module_:__MODULE__ ~location:__LOC__
      "Triggering bootstrap on %d" node ;
    restart_and_payment testnet ~largest_account_keypair ~node ~logger
      ~duration:bootstrap_wait_duration ~payment_receiver
end
