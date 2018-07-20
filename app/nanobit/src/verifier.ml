open Core
open Async
open Nanobit_base
open Util
open Blockchain_snark
open Cli_lib
open Snark_params

module type S = sig
  type t

  val create : conf_dir:string -> t Deferred.t

  val verify_blockchain :
    t -> Blockchain_snark.Blockchain.t -> bool Or_error.t Deferred.t

  val verify_transaction_snark :
    t -> Transaction_snark.t -> bool Or_error.t Deferred.t
end

module Worker_state = struct
  module type S = sig
    val verify_wrap : Blockchain_state.t -> Tock.Proof.t -> bool

    val verify_transaction_snark : Transaction_snark.t -> bool
  end

  type init_arg = unit [@@deriving bin_io]

  type t = (module S)

  let create () : t Deferred.t =
    let%map bc_vk = Snark_keys.blockchain_verification ()
    and tx_vk = Snark_keys.transaction_verification () in
    let module T = Transaction_snark.Verification.Make (struct
      let keys = tx_vk
    end) in
    let module B = Blockchain_transition.Make (T) in
    let module U = Blockchain_snark_utils.Verification (struct
      let key = bc_vk.wrap

      let key_to_bool_list = B.Step_base.Verifier.Verification_key.to_bool_list

      let input = B.wrap_input
    end) in
    let module M = struct
      let verify_wrap = U.verify_wrap

      let verify_transaction_snark = T.verify
    end in
    (module M : S)
end

module Worker = struct
  module T = struct
    module F = Rpc_parallel.Function

    type 'w functions =
      { verify_blockchain: ('w, Blockchain.t, bool) F.t
      ; verify_transaction_snark: ('w, Transaction_snark.t, bool) F.t }

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
      let verify_blockchain (module M : Worker_state.S) (chain: Blockchain.t) =
        return (M.verify_wrap chain.state chain.proof)

      let verify_transaction_snark (module M : Worker_state.S)
          (s: Transaction_snark.t) =
        return (M.verify_transaction_snark s)

      let functions =
        let f (i, o, f) =
          C.create_rpc
            ~f:(fun ~worker_state ~conn_state i -> f worker_state i)
            ~bin_input:i ~bin_output:o ()
        in
        { verify_blockchain=
            f (Blockchain.Stable.V1.bin_t, Bool.bin_t, verify_blockchain)
        ; verify_transaction_snark=
            f (Transaction_snark.bin_t, Bool.bin_t, verify_transaction_snark)
        }

      let init_worker_state () = Worker_state.create ()

      let init_connection_state ~connection:_ ~worker_state:_ = return
    end
  end

  include Rpc_parallel.Make (T)
end

type t = Worker.Connection.t

let create ~conf_dir =
  Parallel.init_master () ;
  Worker.spawn_exn ~on_failure:Error.raise ~shutdown_on:Disconnect
    ~redirect_stdout:(`File_append (conf_dir ^/ "verifier-stdout"))
    ~redirect_stderr:(`File_append (conf_dir ^/ "verifier-stderr"))
    ~connection_state_init_arg:() ()

let verify_blockchain t chain =
  Worker.Connection.run t ~f:Worker.functions.verify_blockchain ~arg:chain

let verify_transaction_snark t snark =
  Worker.Connection.run t ~f:Worker.functions.verify_transaction_snark
    ~arg:snark
