open Core_kernel

type snark_work_generated =
  | Merge_generated of Time.Span.t
  | Base_generated of
      { transaction_type :
          [ `Zkapp_command | `Signed_command | `Coinbase | `Fee_transfer ]
      ; elapsed : Time.Span.t
      ; zkapp_command_count : int
      ; proof_zkapp_command_count : int
      }
  | Sub_zkapp_command of { kind : [ `Merge | `Segment ]; elapsed : Time.Span.t }

val emit_proof_metrics :
  result:Partitioned_result.Stable.V1.t -> snark_work_generated
