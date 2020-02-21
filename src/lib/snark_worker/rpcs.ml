open Core_kernel
open Async
open Coda_base
open Signature_lib

(* for versioning of the types here, see

   RFC 0012, and

   https://ocaml.janestreet.com/ocaml-core/latest/doc/async_rpc_kernel/Async_rpc_kernel/Versioned_rpc/

*)

module Make (Inputs : Intf.Inputs_intf) = struct
  open Inputs
  open Snark_work_lib

  module Get_work = struct
    module Master = struct
      let name = "get_work"

      module T = struct
        (* "master" types, do not change *)

        type query = unit

        type response =
          ( ( Transaction.t Transaction_protocol_state.t
            , Transaction_witness.t
            , Ledger_proof.t )
            Work.Single.Spec.t
            Work.Spec.t
          * Public_key.Compressed.t )
          option
      end

      module Caller = T
      module Callee = T
    end

    include Master.T
    module M = Versioned_rpc.Both_convert.Plain.Make (Master)
    include M

    module V2 = struct
      module T = struct
        type query = unit [@@deriving bin_io, version {rpc}]

        type response =
          ( ( Transaction.Stable.V2.t Transaction_protocol_state.Stable.V1.t
            , Transaction_witness.Stable.V2.t
            , Ledger_proof.Stable.V1.t )
            Work.Single.Spec.Stable.V1.t
            Work.Spec.Stable.V1.t
          * Public_key.Compressed.Stable.V1.t )
          option
        [@@deriving bin_io, version {rpc}]

        let query_of_caller_model = Fn.id

        let callee_model_of_query = Fn.id

        let response_of_callee_model = Fn.id

        let caller_model_of_response = Fn.id
      end

      include T
      include Register (T)
    end

    module V1 = struct
      module T = struct
        type query = unit [@@deriving bin_io, version {rpc}]

        type response =
          ( ( Transaction.Stable.V1.t Transaction_protocol_state.Stable.V1.t
            , Transaction_witness.Stable.V1.t
            , Ledger_proof.Stable.V1.t )
            Work.Single.Spec.Stable.V1.t
            Work.Spec.Stable.V1.t
          * Public_key.Compressed.Stable.V1.t )
          option
        [@@deriving bin_io, version {rpc}]

        let query_of_caller_model = Fn.id

        let callee_model_of_query = Fn.id

        let response_of_callee_model t =
          let open Option.Let_syntax in
          let%bind work, pk = t in
          let%map work =
            match
              Work.Spec.Stable.V1.of_latest
                (Work.Single.Spec.Stable.V1.of_latest
                   (Transaction_protocol_state.Stable.V1.of_latest
                      Transaction.Stable.V1.of_latest)
                   Transaction_witness.Stable.V1.of_latest
                   Ledger_proof.Stable.V1.of_latest)
                work
            with
            | Ok work ->
                Some work
            | Error _ ->
                None
          in
          (work, pk)

        let caller_model_of_response =
          Option.map ~f:(fun (work, pk) ->
              let work =
                Work.Spec.Stable.V1.to_latest
                  (Work.Single.Spec.Stable.V1.to_latest
                     (Transaction_protocol_state.Stable.V1.to_latest
                        Transaction.Stable.V1.to_latest)
                     Transaction_witness.Stable.V1.to_latest
                     Ledger_proof.Stable.V1.to_latest)
                  work
              in
              (work, pk) )
      end

      include T
      include Register (T)
    end

    module Latest = V2
  end

  module Submit_work = struct
    module Master = struct
      let name = "submit_work"

      module T = struct
        (* "master" types, do not change *)
        type query =
          ( ( Transaction.t Transaction_protocol_state.t
            , Transaction_witness.t
            , Ledger_proof.t )
            Work.Single.Spec.t
            Work.Spec.t
          , Ledger_proof.t )
          Work.Result.t

        type response = unit
      end

      module Caller = T
      module Callee = T
    end

    include Master.T
    include Versioned_rpc.Both_convert.Plain.Make (Master)

    module V2 = struct
      module T = struct
        type query =
          ( ( Transaction.Stable.V2.t Transaction_protocol_state.Stable.V1.t
            , Transaction_witness.Stable.V2.t
            , Ledger_proof.Stable.V1.t )
            Work.Single.Spec.Stable.V1.t
            Work.Spec.Stable.V1.t
          , Ledger_proof.Stable.V1.t )
          Work.Result.Stable.V1.t
        [@@deriving bin_io, version {rpc}]

        type response = unit [@@deriving bin_io, version {rpc}]

        let query_of_caller_model : Master.Caller.query -> query = Fn.id

        let callee_model_of_query = Fn.id

        let response_of_callee_model = Fn.id

        let caller_model_of_response = Fn.id
      end

      include T
      include Register (T)
    end

    (* TODO: Retire. We can't convert between this and the latest version. *)
    module V1 = struct
      module T = struct
        type query =
          ( ( Transaction.Stable.V1.t Transaction_protocol_state.Stable.V1.t
            , Transaction_witness.Stable.V1.t
            , Ledger_proof.Stable.V1.t )
            Work.Single.Spec.Stable.V1.t
            Work.Spec.Stable.V1.t
          , Ledger_proof.Stable.V1.t )
          Work.Result.Stable.V1.t
        [@@deriving bin_io, version {rpc}]

        type response = unit [@@deriving bin_io, version {rpc}]

        let query_of_caller_model = Fn.id

        let callee_model_of_query = Fn.id

        let response_of_callee_model = Fn.id

        let caller_model_of_response = Fn.id
      end

      include T
    end

    module Latest = V2
  end
end
