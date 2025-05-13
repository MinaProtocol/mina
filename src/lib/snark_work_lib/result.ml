(*
   This file tracks the Work distributed by Work_selector, hence the name.
   When a SNARK worker requests for work, the work selector is responsible for
   selecting works from a work pool, partitioning them to single proof level
   spec. When a SNARK worker submits a result, the work selector is responsible
   for merging them together.

   All types are versioned, because Works distributed by the selector would need
   to be passed around the network between Coordinater and Snark Worker.
 *)

open Core_kernel

module Poly = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type ('witness, 'zkapp_command_segment_witness, 'ledger_proof, 'metric) t =
        { (* Throw everything inside the spec to ensure proofs, metrics have correct shape *)
          data : unit
              (* ( 'witness *)
              (* , 'zkapp_command_segment_witness *)
              (* , 'ledger_proof *)
              (* , 'metric ) *)
              (* Spec.Poly.Stable.V1.t *)
        ; prover : Signature_lib.Public_key.Compressed.Stable.V1.t
        }

      (* let to_spec ({ data; _ } : _ t) : _ Spec.Poly.t = *)
      (*   match data with *)
      (*   | Spec.Poly.Single { single_spec; pairing; _ } -> *)
      (*       Spec.Poly.Single { single_spec; pairing; metric = () } *)
      (*   | Spec.Poly.Sub_zkapp_command { spec; _ } -> *)
      (*       Spec.Poly.Sub_zkapp_command { spec; metric = () } *)
      (*   | Spec.Poly.Old { instances } -> *)
      (*       Spec.Poly.Old *)
      (*         { instances = *)
      (*             One_or_two.map ~f:(fun (spec, _) -> (spec, ())) instances *)
      (*         } *)
      (***)
      (* let map ~f_witness ~f_zkapp_command_segment_witness ~f_proof ~f_metric *)
      (*     ({ data; prover } : _ t) = *)
      (*   { data = *)
      (*       Spec.Poly.map ~f_witness ~f_zkapp_command_segment_witness ~f_proof *)
      (*         ~f_metric data *)
      (*   ; prover *)
      (*   } *)
    end
  end]

  (* [%%define_locally Stable.Latest.(to_spec, map)] *)
end

(* [%%versioned *)
(* module Stable = struct *)
(*   [@@@no_toplevel_latest_type] *)
(***)
(*   module V1 = struct *)
(*     type t = *)
(*       ( Transaction_witness.Stable.V2.t *)
(*       , Transaction_snark.Zkapp_command_segment.Witness.Stable.V1.t *)
(*       , Ledger_proof.Stable.V2.t *)
(*       , Proof_with_metric.Stable.V1.t ) *)
(*       Poly.Stable.V1.t *)
(***)
(*     let to_latest = Fn.id *)
(*   end *)
(* end] *)
(***)
(* type t = *)
(*   ( Transaction_witness.t *)
(*   , Transaction_snark.Zkapp_command_segment.Witness.t *)
(*   , Ledger_proof.Cached.t *)
(*   , Proof_with_metric.t ) *)
(*   Poly.t *)
(***)
(* let read_all_proofs_from_disk = *)
(*   Poly.map ~f_witness:Transaction_witness.read_all_proofs_from_disk *)
(*     ~f_zkapp_command_segment_witness: *)
(*       Transaction_witness.Zkapp_command_segment_witness *)
(*       .read_all_proofs_from_disk *)
(*     ~f_proof:Ledger_proof.Cached.read_proof_from_disk *)
(*     ~f_metric:Proof_with_metric.read_all_proofs_from_disk *)
(***)
(* let write_all_proofs_to_disk ~proof_cache_db = *)
(*   Poly.map *)
(*     ~f_witness:(Transaction_witness.write_all_proofs_to_disk ~proof_cache_db) *)
(*     ~f_zkapp_command_segment_witness: *)
(*       (Transaction_witness.Zkapp_command_segment_witness *)
(*        .write_all_proofs_to_disk ~proof_cache_db ) *)
(*     ~f_proof:(Ledger_proof.Cached.write_proof_to_disk ~proof_cache_db) *)
(*     ~f_metric:(Proof_with_metric.write_all_proofs_to_disk ~proof_cache_db) *)
