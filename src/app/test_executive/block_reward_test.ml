open Core
open Integration_test_lib
open Mina_base

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  open Inputs
  open Engine
  open Dsl

  open Test_common.Make (Inputs)

  let test_name = "block-reward"

  let config =
    let open Test_config in
    { default with
      genesis_ledger =
        [ { account_name = "node-key"; balance = "1000"; timing = Untimed } ]
    ; block_producers = [ { node_name = "node"; account_name = "node-key" } ]
    }

  let run network t =
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let all_nodes = Network.all_nodes network in
    let%bind () =
      wait_for t
        (Wait_condition.nodes_to_initialize (Core.String.Map.data all_nodes))
    in
    let node =
      Core.String.Map.find_exn (Network.block_producers network) "node"
    in
    let bp_keypair =
      (Core.String.Map.find_exn (Network.genesis_keypairs network) "node-key")
        .keypair
    in
    let bp_pk = bp_keypair.public_key |> Signature_lib.Public_key.compress in
    let bp_pk_account_id = Account_id.create bp_pk Token_id.default in
    let bp_original_balance = Currency.Amount.of_mina_string_exn "1000" in
    let coinbase_reward = Currency.Amount.of_mina_string_exn "720" in
    let%bind () =
      section_hard "wait for 1 block to be produced"
        (wait_for t (Wait_condition.blocks_to_be_produced 1))
    in
    section
      "check that the account balances are what we expect after the block has \
       been produced"
      (let%bind { total_balance = bp_balance; _ } =
         Network.Node.must_get_account_data ~logger node
           ~account_id:bp_pk_account_id
       in
       (* TODO, the intg test framework is ignoring test_constants.coinbase_amount for whatever reason, so hardcoding this until that is fixed *)
       let bp_expected =
         Currency.Amount.add bp_original_balance coinbase_reward
         |> Option.value_exn
       in
       [%log info] "bp_expected: %s"
         (Currency.Amount.to_mina_string bp_expected) ;
       [%log info] "bp_balance: %s" (Currency.Balance.to_mina_string bp_balance) ;
       if
         Currency.Amount.( = )
           (Currency.Balance.to_amount bp_balance)
           bp_expected
       then Malleable_error.return ()
       else
         Malleable_error.soft_error_format ~value:()
           "Error with account balances.  bp balance is %d and should be %d"
           (Currency.Balance.to_nanomina_int bp_balance)
           (Currency.Amount.to_nanomina_int bp_expected) )
end
