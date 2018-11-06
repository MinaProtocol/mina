[%%import
"../../../config.mlh"]

open Core
open Async
open Coda_base
open Util
open Blockchain_snark
open Cli_lib
open Snark_params

module type S = sig
  type blockchain

  type t

  val create : conf_dir:string -> t Deferred.t

  val verify_blockchain : t -> blockchain -> bool Or_error.t Deferred.t

  val verify_transaction_snark :
       t
    -> Transaction_snark.t
    -> message:Sok_message.t
    -> bool Or_error.t Deferred.t
end

module Make
    (Consensus_mechanism : Consensus.Mechanism.S)
    (Blockchain : Blockchain.S
                  with module Consensus_mechanism = Consensus_mechanism) :
  S with type blockchain := Blockchain.t = struct
  module Worker_state = struct
    module type S = sig
      val verify_wrap :
        Consensus_mechanism.Protocol_state.value -> Tock.Proof.t -> bool

      val verify_transaction_snark :
        Transaction_snark.t -> message:Sok_message.t -> bool
    end

    type init_arg = unit [@@deriving bin_io]

    type t = (module S) Deferred.t

    let create () : t Deferred.t =
      Deferred.return
        (let%map bc_vk = Snark_keys.blockchain_verification ()
         and tx_vk = Snark_keys.transaction_verification () in
         let module T = Transaction_snark.Verification.Make (struct
           let keys = tx_vk
         end) in
         let module B = Blockchain_transition.Make (Consensus_mechanism) (T) in
         let module U =
           Blockchain_snark_utils.Verification
             (Consensus_mechanism)
             (struct
               let key = bc_vk.wrap

               let key_to_bool_list =
                 let open B.Step_base.Verifier.Verification_key_data in
                 Fn.compose to_bits full_data_of_verification_key
             end)
         in
         let module M = struct
           let verify_wrap = U.verify_wrap

           let verify_transaction_snark = T.verify
         end in
         (module M : S))

    let get = Fn.id
  end

  module Worker = struct
    module T = struct
      module F = Rpc_parallel.Function

      type 'w functions =
        { verify_blockchain: ('w, Blockchain.t, bool) F.t
        ; verify_transaction_snark:
            ('w, Transaction_snark.t * Sok_message.t, bool) F.t }

      module Worker_state = Worker_state

      module Connection_state = struct
        type init_arg = unit [@@deriving bin_io]

        type t = unit
      end

      module Functions
          (C : Rpc_parallel.Creator
               with type worker_state := Worker_state.t
                and type connection_state := Connection_state.t) =
      struct
        [%%if
        with_snark]

        let verify_blockchain (w : Worker_state.t) (chain : Blockchain.t) =
          let%map (module M) = Worker_state.get w in
          M.verify_wrap chain.state chain.proof

        [%%else]

        let verify_blockchain (w : Worker_state.t) (chain : Blockchain.t) =
          Deferred.return true

        [%%endif]

        let verify_transaction_snark (w : Worker_state.t) (p, message) =
          let%map (module M) = Worker_state.get w in
          M.verify_transaction_snark p ~message

        let functions =
          let f (i, o, f) =
            C.create_rpc
              ~f:(fun ~worker_state ~conn_state i -> f worker_state i)
              ~bin_input:i ~bin_output:o ()
          in
          { verify_blockchain=
              f (Blockchain.bin_t, Bool.bin_t, verify_blockchain)
          ; verify_transaction_snark=
              f
                ( [%bin_type_class: Transaction_snark.t * Sok_message.t]
                , Bool.bin_t
                , verify_transaction_snark ) }

        let init_worker_state () = Worker_state.create ()

        let init_connection_state ~connection:_ ~worker_state:_ = return
      end
    end

    include Rpc_parallel.Make (T)
  end

  type t = Worker.Connection.t

  let create ~conf_dir =
    let%map connection, process =
      Worker.spawn_in_foreground_exn ~connection_timeout:(Time.Span.of_min 1.)
        ~on_failure:Error.raise ~shutdown_on:Disconnect
        ~connection_state_init_arg:() ()
    in
    File_system.dup_stdout process ;
    File_system.dup_stderr process ;
    connection

  let verify_blockchain t chain =
    Worker.Connection.run t ~f:Worker.functions.verify_blockchain ~arg:chain

  let verify_transaction_snark t snark ~message =
    Worker.Connection.run t ~f:Worker.functions.verify_transaction_snark
      ~arg:(snark, message)
end
