open Core_kernel
open Async_kernel
open Nanobit_base
open Main

module Main_mem_for_tests (Init : Init_intf) = struct
  module No_snark = Main_without_snark(Init)
  module Init = No_snark.Init
  module Ledger_proof = No_snark.Ledger_proof
  module State_proof = No_snark.State_proof
  module Bundle = No_snark.Bundle
  module Difficulty = struct
    include Difficulty

    let is_trivial = ref false

    let meets _ _ = !is_trivial

    let make_impossible () =
      is_trivial := false

    let make_trivial () =
      is_trivial := true
  end
  module Inputs =
    Make_inputs(Init)(Ledger_proof)(State_proof)(Difficulty)(Storage.Memory)(Bundle)
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

let run_test : unit -> unit Deferred.t = fun () ->
  let log = Logger.create () in
  let%bind prover = Prover.create ~conf_dir:"/tmp" in
  let%bind genesis_proof = Prover.genesis_proof prover >>| Or_error.ok_exn in
  let module Init : Init_intf = struct
    type proof = Proof.Stable.V1.t [@@deriving bin_io]
    let conf_dir = "/tmp"
    let prover = prover
    let genesis_proof = genesis_proof
  end
  in
  let module Main = Main_mem_for_tests(Init) in
  let module Difficulty = Main.Difficulty in
  let module Run = Run(Main) in
  let open Main in
  let net_config = 
    { Inputs.Net.Config.parent_log = log
    ; gossip_net_params =
        { timeout = Time.Span.of_sec 1.
        ; target_peer_count = 8
        ; address = Host_and_port.of_string "127.0.0.1:8001"
        }
    ; initial_peers = []
    ; me = Host_and_port.of_string "127.0.0.1:8000"
    ; remap_addr_port = Fn.id
    }
  in
  let%bind minibit =
    Main.create
      { log
      ; net_config
      ; ledger_disk_location = "ledgers"
      ; pool_disk_location = "transaction_pool"
      }
  in
  let open Genesis_ledger in
  let assert_balance pk amount =
    match%map
      Run.get_balance minibit pk
    with
    | Some balance ->
        if not (Currency.Balance.equal balance amount) then begin
          failwithf !"Balance in account %{sexp: Currency.Balance.t} is not asserted balance %{sexp: Currency.Balance.t}" balance amount ();
        end
    | None -> failwith "No balance in ledger"
  in

  Run.run ~minibit ~log;
  (* Let the system settle *)
  let%bind () =
    Async.after (Time.Span.of_ms 100.)
  in
  (* Check if rich-man has some balance *)
  let%bind () =
    assert_balance rich_pk initial_rich_balance
  in
  let%bind () =
    assert_balance poor_pk initial_poor_balance
  in

  (* HACK: This is slightly less than all of the initial_rich_balance
   *       so the transaction can't be replayed (before implementing
   *       transaction nonces)
   *)
  let send_amount =
    Currency.Amount.of_string
      (Currency.Balance.to_string (
       Currency.Balance.(-) initial_rich_balance (Currency.Amount.of_int 50) |> Option.value_exn
      ))
  in

  (* Send money to someone *)
  let poor_pk = Genesis_ledger.poor_pk in
  let payload : Transaction.Payload.t =
    { Transaction.Payload.receiver = poor_pk |> Public_key.compress
    ; amount   = send_amount
    ; fee      = Currency.Fee.of_int 0
    }
  in
  let transaction =
    Transaction.sign
      (Signature_keypair.of_private_key rich_sk)
      payload
  in
  let%bind o = Run.send_txn log minibit (transaction :> Transaction.t) in
  let () = Option.value_exn o in
  (* Let the system settle *)
  let%bind () =
    Async.after (Time.Span.of_ms 50.)
  in
  (* Mine some blocks *)
  Difficulty.make_trivial ();
  let%bind () =
    Async.after (Time.Span.of_ms 50.)
  in
  Difficulty.make_impossible ();

  let%bind () =
    assert_balance poor_pk (Currency.Balance.(+) Genesis_ledger.initial_poor_balance send_amount |> Option.value_exn)
  in
  let%map () =
    assert_balance rich_pk (Currency.Balance.(-) Genesis_ledger.initial_rich_balance send_amount |> Option.value_exn)
  in
  ()

let command =
  let open Core in
  let open Async in
  Command.async ~summary:"Full minibit end-to-end test"
    (Command.Param.return run_test)


