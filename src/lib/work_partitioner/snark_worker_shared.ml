open Core_kernel
open Mina_base
open Mina_stdlib
open Transaction_snark

module Zkapp_command_inputs = struct
  [%%versioned
  module Stable = struct
    [@@@no_toplevel_latest_type]

    module V2 = struct
      type t =
        ( Zkapp_command_segment.Witness.Stable.V2.t
        * Zkapp_command_segment.Basic.Stable.V1.t
        * Statement.With_sok.Stable.V2.t )
        Nonempty_list.Stable.V1.t
      [@@deriving sexp, to_yojson]

      let to_latest = Fn.id
    end
  end]

  type t =
    ( Zkapp_command_segment.Witness.t
    * Zkapp_command_segment.Basic.t
    * Statement.With_sok.t )
    Nonempty_list.t

  let write_all_proofs_to_disk ~proof_cache_db : Stable.Latest.t -> t =
    Nonempty_list.map ~f:(fun (witness, segment, stmt) ->
        ( Zkapp_command_segment.Witness.write_all_proofs_to_disk ~proof_cache_db
            witness
        , segment
        , stmt ) )

  let read_all_proofs_from_disk : t -> Stable.Latest.t =
    Nonempty_list.map ~f:(fun (witness, segment, stmt) ->
        ( Zkapp_command_segment.Witness.read_all_proofs_from_disk witness
        , segment
        , stmt ) )
end

module Failed_to_generate_inputs = struct
  type t = [ `Failed_to_generate_inputs of Zkapp_command.t * Error.t ]

  (* TODO: remove this after fully delivering the snark worker
     optimization PR series *)
  let error_of_t (`Failed_to_generate_inputs (tx, e) : t) =
    Error.tag_s e
      ~tag:
        ( Zkapp_command.Stable.Latest.sexp_of_t
        @@ Zkapp_command.read_all_proofs_from_disk tx )
    |> Error.tag ~tag:"failed to generate inputs for zkapp command"
end

let extract_zkapp_segment_works ~m:(module M : S)
    ~(input : Mina_state.Snarked_ledger_state.t)
    ~(witness : Transaction_witness.Stable.Latest.t)
    ~(zkapp_command : Zkapp_command.t) :
    (Zkapp_command_inputs.t, Failed_to_generate_inputs.t) Result.t =
  let inputs =
    Or_error.try_with (fun () ->
        Transaction_snark.zkapp_command_witnesses_exn
          ~signature_kind:M.signature_kind
          ~constraint_constants:M.constraint_constants
          ~global_slot:witness.block_global_slot
          ~state_body:witness.protocol_state_body
          ~fee_excess:Currency.Amount.Signed.zero
          [ ( `Pending_coinbase_init_stack witness.init_stack
            , `Pending_coinbase_of_statement
                { Transaction_snark.Pending_coinbase_stack_state.source =
                    input.source.pending_coinbase_stack
                ; target = input.target.pending_coinbase_stack
                }
            , `Sparse_ledger witness.first_pass_ledger
            , `Sparse_ledger witness.second_pass_ledger
            , `Connecting_ledger_hash input.connecting_ledger_left
            , zkapp_command )
          ]
        |> List.rev )
  in
  match inputs with
  | Error e ->
      Result.fail (`Failed_to_generate_inputs (zkapp_command, e))
  | Ok (first_segment :: rest_segments) ->
      Ok (Nonempty_list.init first_segment rest_segments)
  | Ok [] ->
      (* TODO: erase this branch by refactor underlying
         [Transaction_snark.zkapp_command_witnesses_exn] using nonempty
         list. Also, should consider fusing this function with that to one,
         as this is the only callsite. *)
      failwith "No witness generated"
