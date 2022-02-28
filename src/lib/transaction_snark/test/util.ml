open Base
open Currency
open Mina_base
open Snark_params.Tick
module Impl = Pickles.Impls.Step
module Parties_segment = Transaction_snark.Parties_segment
module Statement = Transaction_snark.Statement

let constraint_constants = Genesis_constants.Constraint_constants.for_unit_tests

let genesis_constants = Genesis_constants.for_unit_tests

let proof_level = Genesis_constants.Proof_level.for_unit_tests

let consensus_constants =
  Consensus.Constants.create ~constraint_constants
    ~protocol_constants:genesis_constants.protocol

module Ledger = struct
  include Mina_ledger.Ledger

  let merkle_root t = Frozen_ledger_hash.of_ledger_hash @@ merkle_root t
end

module Sparse_ledger = struct
  include Mina_ledger.Sparse_ledger

  let merkle_root t = Frozen_ledger_hash.of_ledger_hash @@ merkle_root t
end

let ledger_depth = constraint_constants.ledger_depth

include Transaction_snark.Make (struct
  let constraint_constants = constraint_constants

  let proof_level = proof_level
end)

let state_body =
  let compile_time_genesis =
    (*not using Precomputed_values.for_unit_test because of dependency cycle*)
    Mina_state.Genesis_protocol_state.t
      ~genesis_ledger:Genesis_ledger.(Packed.t for_unit_tests)
      ~genesis_epoch_data:Consensus.Genesis_epoch_data.for_unit_tests
      ~constraint_constants ~consensus_constants
  in
  compile_time_genesis.data |> Mina_state.Protocol_state.body

let init_stack = Pending_coinbase.Stack.empty

let apply_parties ledger parties =
  let witnesses =
    Transaction_snark.parties_witnesses_exn ~constraint_constants ~state_body
      ~fee_excess:Amount.Signed.zero ~pending_coinbase_init_stack:init_stack
      (`Ledger ledger) parties
  in
  let open Impl in
  List.fold ~init:((), ()) witnesses
    ~f:(fun _ (witness, spec, statement, snapp_stmt) ->
      run_and_check
        (fun () ->
          let s =
            exists Statement.With_sok.typ ~compute:(fun () -> statement)
          in
          let snapp_stmt =
            Option.value_map ~default:[] snapp_stmt ~f:(fun (i, stmt) ->
                [ (i, exists Snapp_statement.typ ~compute:(fun () -> stmt)) ])
          in
          Transaction_snark.Base.Parties_snark.main ~constraint_constants
            (Parties_segment.Basic.to_single_list spec)
            snapp_stmt s ~witness ;
          fun () -> ())
        ()
      |> Or_error.ok_exn)

let dummy_rule self : _ Pickles.Inductive_rule.t =
  { identifier = "dummy"
  ; prevs = [ self; self ]
  ; main_value = (fun [ _; _ ] _ -> [ true; true ])
  ; main =
      (fun [ _; _ ] _ ->
        Transaction_snark.dummy_constraints ()
        |> Snark_params.Tick.Run.run_checked
        |> fun () ->
        (* Unsatisfiable. *)
        Run.exists Field.typ ~compute:(fun () -> Run.Field.Constant.zero)
        |> fun s ->
        Run.Field.(Assert.equal s (s + one))
        |> fun () :
               (Snapp_statement.Checked.t * (Snapp_statement.Checked.t * unit))
               Pickles_types.Hlist0.H1
                 (Pickles_types.Hlist.E01(Pickles.Inductive_rule.B))
               .t ->
        [ Boolean.true_; Boolean.true_ ])
  }
