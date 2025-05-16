open Core_kernel
open Async
open Mina_base
open Transaction_snark

(* NOTE:
   This is used in both Work_partitioner and Snark_worker for compatibility
   reasons
*)

module Zkapp_command_inputs : sig
  [%%versioned:
  module Stable : sig
    [@@@no_toplevel_latest_type]

    module V1 : sig
      type t =
        ( Zkapp_command_segment.Witness.Stable.V1.t
        * Zkapp_command_segment.Basic.Stable.V1.t
        * Statement.With_sok.Stable.V2.t )
        list
      [@@deriving sexp, to_yojson]

      val to_latest : t -> t
    end
  end]

  type t =
    ( Zkapp_command_segment.Witness.t
    * Zkapp_command_segment.Basic.t
    * Statement.With_sok.t )
    list

  val write_all_proofs_to_disk :
    proof_cache_db:Proof_cache_tag.cache_db -> Stable.V1.t -> t

  val read_all_proofs_from_disk : t -> Stable.V1.t
end

val extract_zkapp_segment_works :
     m:(module S)
  -> input:Statement.t
  -> witness:Transaction_witness.Stable.V2.t
  -> zkapp_command:Zkapp_command.t
  -> Zkapp_command_inputs.t Deferred.Or_error.t
