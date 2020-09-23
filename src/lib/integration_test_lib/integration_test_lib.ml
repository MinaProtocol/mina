open Core_kernel
open Async_kernel

module Container_images = struct
  type t = {coda: string; user_agent: string; bots: string; points: string}
end

module Test_config = struct
  module Block_producer = struct
    type t = {balance: string}
  end

  type t =
    { k: int
    ; delta: int
    ; proof_level: Runtime_config.Proof_keys.Level.t
    ; txpool_max_size: int
    ; block_producers: Block_producer.t list
    ; num_snark_workers: int
    ; snark_worker_fee: string
    ; snark_worker_public_key: string }

  let default =
    { k= 20
    ; delta= 3
    ; proof_level= Full
    ; txpool_max_size= 3000
    ; num_snark_workers= 2
    ; block_producers= []
    ; snark_worker_fee= "0.025"
    ; snark_worker_public_key=
        (let pk, _ = (Lazy.force Coda_base.Sample_keypairs.keypairs).(0) in
         Signature_lib.Public_key.Compressed.to_string pk) }
end

module Test_error = struct
  type t =
    | Remote_error of {node_id: string; error_message: Logger.Message.t}
    | Internal_error of {occurrence_time: Time.t; error: Error.t}

  let internal_error error =
    Internal_error {occurrence_time= Time.now (); error}

  let to_string = function
    | Remote_error {node_id; error_message} ->
        Printf.sprintf "[%s] %s: %s"
          (Time.to_string error_message.timestamp)
          node_id
          (Yojson.Safe.to_string (Logger.Message.to_yojson error_message))
    | Internal_error {occurrence_time; error} ->
        Printf.sprintf "[%s] test_executive: %s"
          (Time.to_string occurrence_time)
          (Error.to_string_hum error)

  let occurrence_time = function
    | Remote_error {error_message; _} ->
        error_message.timestamp
    | Internal_error {occurrence_time; _} ->
        occurrence_time

  module Set = struct
    type nonrec t = {soft_errors: t list; hard_errors: t list}

    let empty = {soft_errors= []; hard_errors= []}

    let soft_singleton err = {empty with soft_errors= [err]}

    let hard_singleton err = {empty with hard_errors= [err]}

    let merge a b =
      { soft_errors= a.soft_errors @ b.soft_errors
      ; hard_errors= a.hard_errors @ b.hard_errors }

    let combine = List.fold_left ~init:empty ~f:merge
  end
end

(** The signature of integration test engines. An integration test engine
 *  provides the core functionality for deploying, monitoring, and
 *  interacting with networks.
 *)
module type Engine_intf = sig
  module Node : sig
    type t

    val start : fresh_state:bool -> t -> unit Deferred.Or_error.t

    val stop : t -> unit Deferred.Or_error.t

    val send_payment :
         logger:Logger.t
      -> t
      -> sender:Signature_lib.Public_key.Compressed.t
      -> receiver:Signature_lib.Public_key.Compressed.t
      -> amount:Currency.Amount.t
      -> fee:Currency.Fee.t
      -> unit Deferred.Or_error.t
  end

  module Network : sig
    type t =
      { namespace: string
      ; constraint_constants: Genesis_constants.Constraint_constants.t
      ; genesis_constants: Genesis_constants.t
      ; block_producers: Node.t list
      ; snark_coordinators: Node.t list
      ; archive_nodes: Node.t list
      ; testnet_log_filter: string }
  end

  module Network_config : sig
    type t

    val expand :
         logger:Logger.t
      -> test_name:string
      -> test_config:Test_config.t
      -> images:Container_images.t
      -> t
  end

  (* TODO: return Deferred.Or_error.t on each of the lifecycle actions? *)
  module Network_manager : sig
    type t

    val create : Network_config.t -> t Deferred.t

    val deploy : t -> Network.t Deferred.t

    val destroy : t -> unit Deferred.t

    val cleanup : t -> unit Deferred.t
  end

  module Log_engine : sig
    type t

    val create :
         logger:Logger.t
      -> network:Network.t
      -> on_fatal_error:(unit -> unit)
      -> t Deferred.Or_error.t

    val destroy : t -> Test_error.Set.t Deferred.Or_error.t

    (** waits until a block is produced with at least one of the following conditions being true
      1. Blockchain length = blocks
      2. epoch of the block = epoch_reached
      3. Has seen some number of slots/epochs crossed/snarked ledgers generated or x milliseconds has passed
    Note: Varying number of snarked ledgers generated because of reorgs is not captured here *)
    val wait_for :
         ?blocks:int
      -> ?epoch_reached:int
      -> ?timeout:[ `Slots of int
                  | `Epochs of int
                  | `Snarked_ledgers_generated of int
                  | `Milliseconds of int64 ]
      -> t
      -> unit Deferred.Or_error.t

    val wait_for_init : Node.t -> t -> unit Deferred.Or_error.t

    (** wait until a payment transaction appears in an added breadcrumb
        num_tries is the maximum number of breadcrumbs to examine
    *)
    val wait_for_payment :
         ?num_tries:int
      -> t
      -> logger:Logger.t
      -> sender:Signature_lib.Public_key.Compressed.t
      -> receiver:Signature_lib.Public_key.Compressed.t
      -> amount:Currency.Amount.t
      -> unit
      -> unit Or_error.t Deferred.t
  end
end

(** The DSL is a monad which is conceptually similar to `Deferred.Or_error.t`,
 *  except that there are 2 types of errors which can be returned at each bind
 *  point in a computation: soft errors, and hard errors. Soft errors do not
 *  effect the control flow of the monad, and are instead accumulated for later
 *  extraction. Hard errors effect the control flow of the monad in the same
 *  way an `Error` constructor for `Or_error.t` would.
 *)
module type DSL_intf = Monad.S

(*
module Make_DSL (Engine : Engine_intf) : DSL_intf = struct
end
*)

(** A test is a functor which produces a configuration and run function from an
 *  implementation of the DSL.
 *)

(*
module Test_intf : functor (DSL : DSL_intf) -> sig
  val config : Test_config.t

  val run : unit -> unit DSL.t
end
*)

module type Test_intf = sig
  type network

  type log_engine

  val config : Test_config.t

  val run : network -> log_engine -> unit Deferred.Or_error.t
end

(* NB: until the DSL is actually implemented, a test just takes in the engine
 * implementation directly. *)
module type Test_functor_intf = functor (Engine : Engine_intf) -> Test_intf
                                                                  with type network =
                                                                              Engine
                                                                              .Network
                                                                              .t
                                                                   and type log_engine =
                                                                              Engine
                                                                              .Log_engine
                                                                              .t
