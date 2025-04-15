open Core_kernel
open Rpcs_types
open Signature_lib
module Work = Snark_work_lib.Work
module Zkapp_command_segment = Transaction_snark.Zkapp_command_segment

(* For versioning of the types here, see:

   - RFC 0013: https://github.com/MinaProtocol/mina/blob/develop/rfcs/0013-rpc-versioning.md
   - https://ocaml.org/p/async_rpc_kernel/v0.14.0/doc/Async_rpc_kernel/Versioned_rpc/index.html
*)

[%%versioned_rpc
module Get_work = struct
  module V3 = struct
    module T = struct
      type query = V2 | V3

      type response =
        (Wire_work.Spec.Stable.V1.t * Public_key.Compressed.Stable.V1.t) option

      let query_of_caller_model = function
        | Rpcs_master.Get_work.V2 ->
            V2
        | V3 ->
            V3

      let callee_model_of_query = function
        | V2 ->
            Rpcs_master.Get_work.V2
        | V3 ->
            V3

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
        ( Regular_work_single.Stable.V1.t Work.Spec.Stable.V1.t
        * Public_key.Compressed.Stable.V1.t )
        option

      let query_of_caller_model = const ()

      let callee_model_of_query = const Rpcs_master.Get_work.V2

      let response_of_callee_model (resp : Rpcs_master.Get_work.response) :
          response =
        let open Option.Let_syntax in
        let%bind work, key = resp in
        let regular_opt (work : Wire_work.Single.Spec.Stable.V1.t) :
            Regular_work_single.t option =
          match work with
          | Regular w ->
              Some w
          | _ ->
              (* WARN: we'd better report to the coordinator we failed rather
                 than ignoring the work*)
              Printf.printf
                "WARN: V2 Worker receving work `Zkapp_command_segment`, which \
                 is out of its capability, work dropped" ;
              None
        in
        let%map work = Work.Spec.map_opt ~f_single:regular_opt work in
        (work, key)

      let caller_model_of_response (resp : response) :
          Rpcs_master.Get_work.response =
        let open Option.Let_syntax in
        let%map work, key = resp in
        let wrap_work w = Wire_work.Single.Spec.Stable.V1.Regular w in
        (Work.Spec.map ~f_single:wrap_work work, key)
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
      type query = Wire_work.Result.Stable.V1.t

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

      let query_of_caller_model : Rpcs_master.Submit_work.query -> query =
        (* function *)
        (* | Regular result -> *)
        (*     result *)
        (* | Zkapp_command_segment _ -> *)
        (*     failwith *)
        (* "FATAL: V2 Worker completed a `Zkapp_command_segment` job where \ *)
           (*        the coordinator can't aggregate, this shouldn't happen as the \ *)
           (*        work is issued by the coordinator" *)
        failwith "TODO"

      let callee_model_of_query (_result : query) :
          Rpcs_master.Submit_work.query =
        (* Regular result *)
        failwith "TODO"

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
      type query = Rpcs_master.Failed_to_generate_snark.query =
        { error : Bounded_types.Wrapped_error.Stable.V1.t
        ; failed_work : Wire_work.Spec.Stable.V1.t
        }

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
       fun _ -> failwith "TODO"

      let callee_model_of_query :
          query -> Rpcs_master.Failed_to_generate_snark.query =
       fun _ -> failwith "TODO"
      (* let query_of_caller_model : *)
      (*     Rpcs_master.Failed_to_generate_snark.query -> query = function *)
      (*   | { error; failed_work = Regular { work_spec; public_key } } -> *)
      (*       (error, work_spec, public_key) *)
      (*   | { failed_work = Zkapp_command_segment _; _ } -> *)
      (*       failwith *)
      (* "FATAL: V2 Worker failed on a `Zkapp_command_segment` job where \ *)
         (*          the coordinator can't aggregate, this shouldn't happen as the \ *)
         (*          work is issued by the coordinator" *)
      (***)
      (* let callee_model_of_query : *)
      (*     query -> Rpcs_master.Failed_to_generate_snark.query = *)
      (*  fun (error, work_spec, public_key) -> *)
      (*   { error; failed_work = Regular { work_spec; public_key } } *)

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
