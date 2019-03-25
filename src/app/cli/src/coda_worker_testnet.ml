open Core
open Async
open Coda_worker
open Coda_main
open Signature_lib
open Coda_base
open Pipe_lib

module Api = struct
  type user_cmd_status = {expected_deadline: int; passed_root: unit Ivar.t}

  type user_cmds_under_inspection = (User_command.t, user_cmd_status) Hashtbl.t

  type t =
    { workers: Coda_process.t list
    ; configs: Coda_worker.Input.t list
    ; start_writer:
        (int * Coda_worker.Input.t * (unit -> unit) * (unit -> unit))
        Linear_pipe.Writer.t
    ; status:
        [`On of [`Synced of user_cmds_under_inspection | `Catchup] | `Off]
        Array.t }

  let create configs workers start_writer =
    let status =
      Array.init (List.length workers) ~f:(fun _ ->
          let user_cmds_under_inspection =
            Hashtbl.create (module User_command)
          in
          `On (`Synced user_cmds_under_inspection) )
    in
    {workers; configs; start_writer; status}

  let online t i = match t.status.(i) with `On _ -> true | `Off -> false

  let synced t i =
    match t.status.(i) with
    | `On (`Synced _) -> true
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
      , fun () ->
          let user_cmds_under_inspection =
            Hashtbl.create (module User_command)
          in
          t.status.(i) <- `On (`Synced user_cmds_under_inspection) )

  let stop t i =
    ( match t.status.(i) with
    | `On (`Synced user_cmds_under_inspection) ->
        Hashtbl.iter user_cmds_under_inspection ~f:(fun {passed_root; _} ->
            Ivar.fill passed_root () )
    | _ -> () ) ;
    t.status.(i) <- `Off ;
    Coda_process.disconnect (List.nth_exn t.workers i)

  let send_payment t i ?acceptable_delay:(delay = 7) sender_sk receiver_pk
      amount fee =
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
    let%bind receipt =
      Coda_process.process_payment_exn worker user_cmd
      |> Deferred.map ~f:Or_error.ok
    in
    let%map (all_passed_root : unit Ivar.t list) =
      let open Deferred.Let_syntax in
      Deferred.List.filter_map (t.status |> Array.to_list) ~f:(function
        | `On (`Synced user_cmds_under_inspection) ->
            let%map root_length = Coda_process.root_length_exn worker in
            let passed_root = Ivar.create () in
            Hashtbl.add_exn user_cmds_under_inspection ~key:user_cmd
              ~data:
                { expected_deadline= root_length + Consensus.Constants.k + delay
                ; passed_root } ;
            Option.return passed_root
        | _ -> return None )
      >>| Option.return
    in
    all_passed_root

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

let start_payment_check logger root_pipe workers (testnet : Api.t) =
  Linear_pipe.iter root_pipe ~f:(function
      | `Root
          ( worker_id
          , Protocols.Coda_transition_frontier.Root_diff_view.({ user_commands
                                                               ; root_length })
          )
      ->
      Option.fold root_length ~init:Deferred.unit ~f:(fun _ length ->
          match testnet.status.(worker_id) with
          | `On (`Synced user_cmds_under_inspection) ->
              let earliest_user_cmd =
                List.min_elt (Hashtbl.to_alist user_cmds_under_inspection)
                  ~compare:(fun (user_cmd1, status1) (user_cmd2, status2) ->
                    Int.compare status1.expected_deadline
                      status2.expected_deadline )
              in
              Option.iter earliest_user_cmd
                ~f:(fun (user_cmd, {expected_deadline; _}) ->
                  if expected_deadline < length then (
                    Logger.fatal logger ~module_:__MODULE__ ~location:__LOC__
                      ~metadata:
                        [ ("worker_id", `Int worker_id)
                        ; ("user_cmd", User_command.to_yojson user_cmd) ]
                      "transaction $user_cmd took too long to get into the \
                       root of node $worker_id" ;
                    (*exit 1 |> ignore*) failwith "fail here" ) ) ;
              List.iter user_commands ~f:(fun user_cmd ->
                  Hashtbl.change user_cmds_under_inspection user_cmd
                    ~f:(function
                    | Some {passed_root; _} ->
                        Ivar.fill passed_root () ;
                        Logger.info logger ~module_:__MODULE__
                          ~location:__LOC__
                          ~metadata:
                            [ ("user_cmd", User_command.to_yojson user_cmd)
                            ; ("worker_id", `Int worker_id)
                            ; ("length", `Int length) ]
                          "transaction $user_cmd finally gets into the root \
                           of node $worker_id, when root length is $length" ;
                        None
                    | None -> None ) ) ;
              Deferred.unit
          | _ -> Deferred.unit ) )
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

let start_checks logger workers start_reader testnet ~acceptable_delay =
  let event_reader, root_reader = events workers start_reader in
  (*start_prefix_check logger workers event_reader testnet ~acceptable_delay ;*)
  start_payment_check logger root_reader workers testnet

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
  let start_reader, start_writer = Linear_pipe.create () in
  let testnet = Api.create configs workers start_writer in
  start_checks logger workers start_reader testnet ~acceptable_delay ;
  testnet

module Payments : sig
  val send_several_payments :
    Api.t -> node:int -> keypairs:Keypair.t list -> n:int -> unit Deferred.t
end = struct
  let send_several_payments testnet ~node ~keypairs ~n =
    let amount = Currency.Amount.of_int 10 in
    let fee = Currency.Fee.of_int 1 in
    let%bind _ : unit option list =
      Deferred.List.init n ~f:(fun _ ->
          let open Deferred.Option.Let_syntax in
          let%bind all_passed_root's =
            List.map
              (keypairs : Keypair.t list)
              ~f:(fun sender_keypair ->
                let receiver_keypair = List.random_element_exn keypairs in
                let sender_sk = sender_keypair.private_key in
                let receiver_pk =
                  receiver_keypair.public_key |> Public_key.compress
                in
                Api.send_payment testnet node sender_sk receiver_pk amount fee
                )
            |> Deferred.Option.all
          in
          Deferred.map
            (Deferred.List.iter (List.concat all_passed_root's) ~f:Ivar.read)
            ~f:(Fn.const (Some ())) )
    in
    Deferred.unit
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
