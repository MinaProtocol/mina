open Core_kernel
open Rpcs_types
open Signature_lib
module Work = Snark_work_lib.Work
module Zkapp_command_segment = Transaction_snark.Zkapp_command_segment

(* For versioning of the types here, see:

   - RFC 0013: https://github.com/MinaProtocol/mina/blob/develop/rfcs/0013-rpc-versioning.md
   - https://ocaml.org/p/async_rpc_kernel/v0.14.0/doc/Async_rpc_kernel/Versioned_rpc/index.html
*)

let regular_opt (work : Wire_work.Single.Spec.Stable.V2.t) :
    Regular_work_single.t option =
  match work with Regular w -> Some w | _ -> None

[%%versioned_rpc
module Get_work = struct
  module V3 = struct
    module T = struct
      type query = [ `V2 | `V3 ]

      type response =
        (Wire_work.Spec.Stable.V2.t * Public_key.Compressed.Stable.V1.t) option

      let query_of_caller_model = Fn.id

      let callee_model_of_query = Fn.id

      let response_of_callee_model : Rpcs_master.Get_work.response -> response =
        Fn.id

      let caller_model_of_response : response -> Rpcs_master.Get_work.response =
        Fn.id
    end

    include T
    include Rpcs_master.Get_work.Register (T)
  end

  module V2 = struct
    module T = struct
      type query = unit

      type response =
        (Wire_work.Spec.Stable.V1.t * Public_key.Compressed.Stable.V1.t) option

      let query_of_caller_model = const ()

      let callee_model_of_query = const `V2

      let response_of_callee_model (resp : Rpcs_master.Get_work.response) :
          response =
        let open Option.Let_syntax in
        let%bind work, key = resp in
        let unwrap_regular_and_warn work =
          match regular_opt work with
          | None ->
              (* WARN: we'd better report to the coordinator we failed rather *)
              (*          than ignoring the work*)
              Printf.printf
                "WARN: V2 Worker receving work `Zkapp_command_segment`, which \
                 is out of its capability, work dropped" ;
              None
          | Some w ->
              Some w
        in
        let%map work =
          Work.Spec.map_opt ~f_single:unwrap_regular_and_warn work
        in
        assert (Option.is_none work.partitioner_auxilaries) ;
        ( ( { instances = work.instances; fee = work.fee }
            : Wire_work.Spec.Stable.V1.t )
        , key )

      let caller_model_of_response (resp : response) :
          Rpcs_master.Get_work.response =
        let open Option.Let_syntax in
        let%map work, key = resp in
        let latest_work = Wire_work.Spec.Stable.V1.to_latest work in
        (latest_work, key)
    end

    include T
    include Rpcs_master.Get_work.Register (T)
  end

  module Latest = V3
end]

[%%versioned_rpc
module Submit_work = struct
  module V3 = struct
    module T = struct
      type query = Wire_work.Result.Stable.V2.t

      type response = unit

      let query_of_caller_model : Rpcs_master.Submit_work.query -> query = Fn.id

      let callee_model_of_query : query -> Rpcs_master.Submit_work.query = Fn.id

      let response_of_callee_model :
          Rpcs_master.Submit_work.response -> response =
        Fn.id

      let caller_model_of_response :
          response -> Rpcs_master.Submit_work.response =
        Fn.id
    end

    include T
    include Rpcs_master.Submit_work.Register (T)
  end

  module V2 = struct
    module T = struct
      type query = Wire_work.Result.Stable.V1.t

      type response = unit

      let fix_metric_tag (span, tag) =
        match tag with
        | (`Transition | `Merge) as tag ->
            Some (span, tag)
        | `Zkapp_command_segment ->
            None

      let query_of_caller_model
          ({ proofs; metrics; spec; prover } : Rpcs_master.Submit_work.query) :
          query =
        let open Option.Let_syntax in
        let fatal_message =
          "FATAL: V2 Worker completed a `Zkapp_command_segment` job where the \
           coordinator can't aggregate, this shouldn't happen as the work is \
           issued by the coordinator"
        in
        (let%bind metrics = One_or_two.Option.map metrics ~f:fix_metric_tag in
         let%map spec = Work.Spec.map_opt ~f_single:regular_opt spec in

         assert (Option.is_none spec.partitioner_auxilaries) ;
         let spec : Wire_work.Spec.Stable.V1.t =
           { instances = spec.instances; fee = spec.fee }
         in
         let result : query = { proofs; metrics; spec; prover } in
         result )
        |> Option.value_exn ~message:fatal_message

      let callee_model_of_query : query -> Rpcs_master.Submit_work.query =
        Wire_work.Result.Stable.V1.to_latest

      let response_of_callee_model :
          Rpcs_master.Submit_work.response -> response =
        Fn.id

      let caller_model_of_response :
          response -> Rpcs_master.Submit_work.response =
        Fn.id
    end

    include T
    include Rpcs_master.Submit_work.Register (T)
  end

  module Latest = V3
end]

[%%versioned_rpc
module Failed_to_generate_snark = struct
  module V3 = struct
    module T = struct
      type query =
        Bounded_types.Wrapped_error.Stable.V1.t
        * Wire_work.Spec.Stable.V2.t
        * Public_key.Compressed.Stable.V1.t

      type response = unit

      let query_of_caller_model :
          Rpcs_master.Failed_to_generate_snark.query -> query =
        Fn.id

      let callee_model_of_query :
          query -> Rpcs_master.Failed_to_generate_snark.query =
        Fn.id

      let response_of_callee_model :
          Rpcs_master.Failed_to_generate_snark.response -> response =
        Fn.id

      let caller_model_of_response :
          response -> Rpcs_master.Failed_to_generate_snark.response =
        Fn.id
    end

    include T
    include Rpcs_master.Failed_to_generate_snark.Register (T)
  end

  module V2 = struct
    module T = struct
      type query =
        Bounded_types.Wrapped_error.Stable.V1.t
        * Wire_work.Spec.Stable.V1.t
        * Public_key.Compressed.Stable.V1.t

      type response = unit

      let query_of_caller_model :
          Rpcs_master.Failed_to_generate_snark.query -> query =
       fun (error, work_spec, public_key) ->
        let open Option.Let_syntax in
        (let%map work_spec =
           Work.Spec.map_opt ~f_single:regular_opt work_spec
         in

         assert (Option.is_none work_spec.partitioner_auxilaries) ;
         let work_spec : Wire_work.Spec.Stable.V1.t =
           { instances = work_spec.instances; fee = work_spec.fee }
         in
         (error, work_spec, public_key) )
        |> Option.value_exn
             ~message:
               "FATAL: V2 Worker failed on a `Zkapp_command_segment` job where \
                the coordinator can't aggregate, this shouldn't happen as the \
                work is issued by the coordinator"

      let callee_model_of_query :
          query -> Rpcs_master.Failed_to_generate_snark.query =
       fun (error, work_spec, public_key) ->
        (error, Wire_work.Spec.Stable.V1.to_latest work_spec, public_key)

      let response_of_callee_model :
          Rpcs_master.Failed_to_generate_snark.response -> response =
        Fn.id

      let caller_model_of_response :
          response -> Rpcs_master.Failed_to_generate_snark.response =
        Fn.id
    end

    include T
    include Rpcs_master.Failed_to_generate_snark.Register (T)
  end

  module Latest = V3
end]
