open Core
open Async
open Nanobit_base
open Blockchain_snark
open Cli_common

module type Init_intf = sig
  type proof [@@deriving bin_io]

  val conf_dir : string
  val prover : Prover.t

  val genesis_proof : proof
end

module Make_inputs0
  (Init : Init_intf)
  (Ledger_proof : Protocols.Minibit_pow.Proof_intf)
  (State_proof : sig
    type t = Init.proof [@@deriving bin_io]
    include Protocols.Minibit_pow.Proof_intf with type input = State.t
                                              and type t := t
  end)
= struct
  module State_proof = State_proof
  module Ledger_proof = Ledger_proof
  module Time = Block_time
  module State_hash = State_hash.Stable.V1
  module Ledger_hash = Ledger_hash.Stable.V1
  module Transaction = Transaction

  module Nonce = Nanobit_base.Nonce

  module Difficulty = Difficulty

  module Pow = Snark_params.Tick.Pedersen.Digest

  module Strength = Strength
  module Ledger = struct
    type t = Nanobit_base.Ledger.t [@@deriving sexp, compare, hash, bin_io]
    type valid_transaction = Transaction.With_valid_signature.t

    let create = Ledger.create
    let merkle_root = Ledger.merkle_root
    let copy = Nanobit_base.Ledger.copy
    let apply_transaction t (valid_transaction : Transaction.With_valid_signature.t) : unit Or_error.t =
      Nanobit_base.Ledger.apply_transaction_unchecked t (valid_transaction :> Transaction.t)
  end

  module Transition = struct
    type t =
      { ledger_hash : Ledger_hash.t
      ; ledger_proof : Ledger_proof.t sexp_opaque
      ; timestamp : Time.t
      ; nonce : Nonce.t
      }
    [@@deriving sexp, fields]
  end

  module Time_close_validator = struct
    let validate t =
      let now_time = Time.now () in
      Time.(diff now_time t < (Span.of_time_span (Core_kernel.Time.Span.of_sec 900.)))
  end

  module State = struct
    include State
    module Proof = State_proof
  end

  module Proof_carrying_state = struct
    type t = (State.t, State.Proof.t sexp_opaque) Protocols.Minibit_pow.Proof_carrying_data.t
    [@@deriving sexp, bin_io]
  end

  module State_with_witness = struct
    type transaction_with_valid_signature = Transaction.With_valid_signature.t
      [@@deriving sexp]
    type transaction = Transaction.t
      [@@deriving sexp, bin_io]
    type witness = Transaction.With_valid_signature.t list
      [@@deriving sexp, bin_io]
    type state = Proof_carrying_state.t 
      [@@deriving sexp, bin_io]
    type t =
      { transactions : witness
      ; state : state
      }
      [@@deriving sexp, bin_io]

    module Stripped = struct
      type witness = Transaction.t list
        [@@deriving bin_io]
      type t =
        { transactions : witness
        ; state : Proof_carrying_state.t
        }
      [@@deriving bin_io]
    end

    let strip t = 
      { Stripped.transactions = (t.transactions :> Transaction.t list)
      ; state = t.state
      }

    let forget_witness {state} = state
    (* TODO should we also consume a ledger here so we know the transactions valid? *)
    let add_witness_exn state transactions =
      {state ; transactions}
    (* TODO same *)
    let add_witness state transactions = Or_error.return {state ; transactions}
  end
  module Transition_with_witness = struct
    type witness = Transaction.With_valid_signature.t list
    [@@deriving sexp]
    type t =
      { transactions : witness
      ; transition : Transition.t
      }
    [@@deriving sexp]

    let forget_witness {transition} = transition
    (* TODO should we also consume a ledger here so we know the transactions valid? *)
    let add_witness_exn transition transactions =
      {transition ; transactions}
    (* TODO same *)
    let add_witness transition transactions = Or_error.return {transition ; transactions}
  end

end
module Make_inputs
  (Init : Init_intf)
  (Ledger_proof : Protocols.Minibit_pow.Proof_intf)
  (State_proof : sig
    type t = Init.proof [@@deriving bin_io]
    include Protocols.Minibit_pow.Proof_intf with type input = State.t
                                              and type t := t
  end)
  (Bundle : Bundle.S with type proof := Ledger_proof.t)
= struct
  module Inputs0 = Make_inputs0(Init)(Ledger_proof)(State_proof)
  include Inputs0
  module Net = Minibit_networking.Make(struct
    module State_with_witness = State_with_witness
    module Ledger_hash = Ledger_hash
    module Ledger = Ledger
    module State = State
  end)
  module Ledger_fetcher_io = Net.Ledger_fetcher_io

  module State_io = Net.State_io

  module Bundle = struct
    include Bundle
    let create ledger ts = create ledger ts ~conf_dir:Init.conf_dir
  end

  module Transaction_pool = Transaction_pool.Make(Transaction)

  module Genesis = struct
    let state : State.t = State.zero
    let proof = Init.genesis_proof
  end
  module Ledger_fetcher = Ledger_fetcher.Make(struct
    include Inputs0
    module Net = Net
    module Store = Storage.Disk
    module Transaction_pool = Transaction_pool
    module Genesis = Genesis
    module Genesis_ledger = Genesis_ledger
  end)

  module Miner = Minibit_miner.Make(struct
    include Inputs0
    module Transaction_pool = Transaction_pool
    module Bundle = Bundle
  end)
end

module Debug_main (Init : Init_intf) = struct
  module Init = struct
    type proof = () [@@deriving bin_io]

    let conf_dir = Init.conf_dir
    let prover = Init.prover
    let genesis_proof = ()
  end

  module Ledger_proof = Ledger_proof.Debug

  module State_proof = State_proof.Make_debug(Init)

  module Bundle = struct
    type t = Ledger_hash.t

    let create ~conf_dir ledger ts =
      let ts_rev =
        List.rev_map ts ~f:(fun txn ->
          ignore (Ledger.apply_transaction ledger txn);
          txn);
      in
      List.iter ts_rev ~f:(fun txn ->
        ignore (Ledger.undo_transaction ledger (txn :> Transaction.t)));
      Ledger.merkle_root ledger

    let cancel (t : t) : unit = ()

    let target_hash t = t

    let result (t : t) =
      (* I need this local variable to convince the type checker *)
      let p : Ledger_proof.t = () in
      Deferred.Option.return p
  end

  module Inputs =
    Make_inputs(Init)(Ledger_proof)(State_proof)(Bundle)

  module Main =
      Minibit.Make(Inputs)(struct
        module Witness = struct
          type t =
            { old_state : Inputs.State.t
            ; old_proof : Inputs.State.Proof.t
            ; transition : Inputs.Transition.t
            }
        end

        let prove_zk_state_valid _ ~new_state:_ = return Inputs.Genesis.proof
      end)
end

module Prod_main
    (Init : Init_intf with type proof = Proof.t)
= struct
  module Ledger_proof = Ledger_proof.Make_prod(Init)
  module State_proof = State_proof.Make_prod(Init)
  module Bundle = struct
    include Bundle
    let result t = Deferred.Option.(result t >>| Transaction_snark.proof)
  end

  module Inputs = Make_inputs(Init)(Ledger_proof)(State_proof)(Bundle)

  module Main =
    Minibit.Make(Inputs)(struct
      module Witness = struct
        type t =
          { old_state : Inputs.State.t
          ; old_proof : Inputs.State.Proof.t
          ; transition : Inputs.Transition.t
          }
      end

      let prove_zk_state_valid ({ old_state; old_proof; transition } : Witness.t) ~new_state:_ =
        Prover.extend_blockchain Init.prover
          { state = State.to_blockchain_state old_state; proof = old_proof }
          { header = { time = transition.timestamp; nonce = transition.nonce }
          ; body = { target_hash = transition.ledger_hash; proof = transition.ledger_proof }
          }
        >>| Or_error.ok_exn
        >>| Blockchain.proof
    end)
end

let daemon =
  let open Command.Let_syntax in
  Command.async
    ~summary:"Current daemon"
    begin
      [%map_open
        let conf_dir =
          flag "config directory"
            ~doc:"Configuration directory"
            (optional file)
        and should_mine =
          flag "mine"
            ~doc:"Run the miner" (required bool)
        and port =
          flag "port"
            ~doc:"Server port for other to connect" (required int16)
        and client_port =
          flag "client-port"
            ~doc:"Port for client to connect daemon locally" (required int16)
        and ip =
          flag "ip"
            ~doc:"External IP address for others to connect" (optional string)
        in
        fun () ->
          let open Deferred.Let_syntax in
          let%bind home = Sys.home_directory () in
          let conf_dir =
            Option.value ~default:(home ^/ ".current-config") conf_dir
          in
          let%bind () = Unix.mkdir ~p:() conf_dir in
          let%bind initial_peers =
            let peers_path = conf_dir ^/ "peers" in
            match%bind Reader.load_sexp peers_path [%of_sexp: Host_and_port.t list] with
            | Ok ls -> return ls
            | Error e -> 
              begin
                let default_initial_peers = [] in
                let%map () = Writer.save_sexp peers_path ([%sexp_of: Host_and_port.t list] default_initial_peers) in
                []
              end
          in
          let log = Logger.create () in
          let%bind ip =
            match ip with
            | None -> Find_ip.find ()
            | Some ip -> return ip
          in
          let remap_addr_port = Fn.id in
          let me = Host_and_port.create ~host:ip ~port in
          let%bind prover = Prover.create ~conf_dir in
          let%bind genesis_proof = Prover.genesis_proof prover >>| Or_error.ok_exn in
          let module Init = struct
            type proof = Proof.Stable.V1.t [@@deriving bin_io]

            let conf_dir = conf_dir
            let prover = prover
            let genesis_proof = genesis_proof
          end
          in
          let module Debug = Debug_main(Init) in
          let module Prod = Prod_main(Init) in
          let%bind () =
          if Insecure.key_generation then begin
            let open Debug in
            let net_config = 
              { Inputs.Net.Config.parent_log = log
              ; gossip_net_params =
                  { timeout = Time.Span.of_sec 1.
                  ; target_peer_count = 8
                  ; address = remap_addr_port me
                  } 
              ; initial_peers
              ; me
              ; remap_addr_port
              }
            in
            let%map minibit =
              Main.create
                { log
                ; net_config
                ; ledger_disk_location = conf_dir ^/ "ledgers"
                ; pool_disk_location = conf_dir ^/ "transaction_pool"
                }
            in
            (* Setup RPC server for client interactions *)
            let module Client_server = Client.Rpc_server(struct
              type t = Main.t
              let get_balance (t : t) (addr : Public_key.Stable.V1.t) =
                let ledger = Inputs.Ledger_fetcher.best_ledger t.ledger_fetcher in
                let key = Public_key.compress addr in
                let maybe_balance =
                  Option.map
                    (Ledger.get ledger key)
                    ~f:(fun account -> account.Account.balance)
                in
                return maybe_balance
              let send_txn (t : t) txn =
                let ledger = Inputs.Ledger_fetcher.best_ledger t.ledger_fetcher in
                match Inputs.Transaction.check txn with
                | Some txn ->
                  let ledger' = Ledger.copy ledger in
                  let () = Inputs.Ledger.apply_transaction ledger' txn |> Or_error.ok_exn in
                  t.Main.transaction_pool <- Inputs.Transaction_pool.add t.Main.transaction_pool txn;
                  Logger.info log !"Added transaction %{sexp: Inputs.Transaction.With_valid_signature.t} to pool successfully" txn;
                  return (Some ())
                | None -> return None
            end) in
            Client_server.init_server
              ~parent_log:log
              ~minibit
              ~port:client_port;

            printf "Created minibit\n%!";
            Main.run minibit;
            printf "Ran minibit\n%!";
          end else begin
            let open Prod in
            let net_config = 
              { Inputs.Net.Config.parent_log = log
              ; gossip_net_params =
                  { timeout = Time.Span.of_sec 1.
                  ; target_peer_count = 8
                  ; address = remap_addr_port me
                  } 
              ; initial_peers
              ; me
              ; remap_addr_port
              }
            in
            let%map minibit =
              Main.create
                { log
                ; net_config
                ; ledger_disk_location = conf_dir ^/ "ledgers"
                ; pool_disk_location = conf_dir ^/ "transaction_pool"
                }
            in
            (* Setup RPC server for client interactions *)
            let module Client_server = Client.Rpc_server(struct
              type t = Main.t
              let get_balance (t : t) (addr : Public_key.Stable.V1.t) =
                let ledger = Inputs.Ledger_fetcher.best_ledger t.ledger_fetcher in
                let key = Public_key.compress addr in
                let maybe_balance =
                  Option.map
                    (Ledger.get ledger key)
                    ~f:(fun account -> account.Account.balance)
                in
                return maybe_balance
              let send_txn (t : t) txn =
                let ledger = Inputs.Ledger_fetcher.best_ledger t.ledger_fetcher in
                match Inputs.Transaction.check txn with
                | Some txn ->
                  let ledger' = Ledger.copy ledger in
                  let () = Inputs.Ledger.apply_transaction ledger' txn |> Or_error.ok_exn in
                  t.Main.transaction_pool <- Inputs.Transaction_pool.add t.Main.transaction_pool txn;
                  Logger.info log !"Added transaction %{sexp: Inputs.Transaction.With_valid_signature.t} to pool successfully" txn;
                  return (Some ())
                | None -> return None
            end) in
            Client_server.init_server
              ~parent_log:log
              ~minibit
              ~port:client_port;

            printf "Created minibit\n%!";
            Main.run minibit;
            printf "Ran minibit\n%!";
          end
              in
          Async.never ()
      ]
    end
;;

let () = 
  Command.group ~summary:"Current"
    [ "daemon", daemon
    ; Parallel.worker_command_name, Parallel.worker_command
    ; "rpc", Main_rpc.command
    ; "client", Client.command
    ]
  |> Command.run
;;

let () = never_returns (Scheduler.go ())
;;
