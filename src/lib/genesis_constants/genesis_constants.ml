open Core_kernel

module Proof_level = struct
  type t = Full | Check | None [@@deriving bin_io_unversioned, equal]

  let to_string = function Full -> "full" | Check -> "check" | None -> "none"

  let of_string = function
    | "full" ->
        Full
    | "check" ->
        Check
    | "none" ->
        None
    | s ->
        failwithf "unrecognised proof level %s" s ()
end

module Fork_constants = struct
  type t =
    { state_hash : Pickles.Backend.Tick.Field.Stable.Latest.t
    ; blockchain_length : Mina_numbers.Length.Stable.Latest.t
    ; global_slot_since_genesis :
        Mina_numbers.Global_slot_since_genesis.Stable.Latest.t
    }
  [@@deriving bin_io_unversioned, sexp, equal, compare, yojson]
end

module Constraint_constants = struct
  type t =
    { sub_windows_per_window : int
    ; ledger_depth : int
    ; work_delay : int
    ; block_window_duration_ms : int
    ; transaction_capacity_log_2 : int
    ; pending_coinbase_depth : int
    ; coinbase_amount : Currency.Amount.Stable.Latest.t
    ; supercharged_coinbase_factor : int
    ; account_creation_fee : Currency.Fee.Stable.Latest.t
    ; fork : Fork_constants.t option
    }
  [@@deriving bin_io_unversioned, sexp, equal, compare, yojson]

  let to_snark_keys_header (t : t) : Snark_keys_header.Constraint_constants.t =
    { sub_windows_per_window = t.sub_windows_per_window
    ; ledger_depth = t.ledger_depth
    ; work_delay = t.work_delay
    ; block_window_duration_ms = t.block_window_duration_ms
    ; transaction_capacity = Log_2 t.transaction_capacity_log_2
    ; pending_coinbase_depth = t.pending_coinbase_depth
    ; coinbase_amount = Currency.Amount.to_uint64 t.coinbase_amount
    ; supercharged_coinbase_factor = t.supercharged_coinbase_factor
    ; account_creation_fee = Currency.Fee.to_uint64 t.account_creation_fee
    ; fork =
        ( match t.fork with
        | Some { blockchain_length; state_hash; global_slot_since_genesis } ->
            Some
              { blockchain_length = Unsigned.UInt32.to_int blockchain_length
              ; state_hash = Pickles.Backend.Tick.Field.to_string state_hash
              ; global_slot_since_genesis =
                  Unsigned.UInt32.to_int
                    (Mina_numbers.Global_slot_since_genesis.to_uint32
                       global_slot_since_genesis )
              }
        | None ->
            None )
    }
end

module Helpers = struct
  (*Constants that can be specified for generating the base proof (that are not required for key-generation) in runtime_genesis_ledger.exe and that can be configured at runtime.
    The types are defined such that this module doesn't depend on any of the coda libraries (except blake2 and module_version) to avoid dependency cycles.
    TODO: #4659 move key generation to runtime_genesis_ledger.exe to include scan_state constants, consensus constants (c and  block_window_duration) and ledger depth here*)

  let genesis_timestamp_of_string str =
    let default_zone = Time.Zone.of_utc_offset ~hours:(-8) in
    Time.of_string_gen
      ~find_zone:(fun _ -> assert false)
      ~default_zone:(fun () -> default_zone)
      str

  let of_time t =
    Time.to_span_since_epoch t |> Time.Span.to_ms |> Int64.of_float

  let to_time t =
    t |> Int64.to_float |> Time.Span.of_ms |> Time.of_span_since_epoch

  let validate_time time_str =
    match
      Result.try_with (fun () ->
          Option.value_map ~default:(Time.now ()) ~f:genesis_timestamp_of_string
            time_str )
    with
    | Ok time ->
        Ok (of_time time)
    | Error _ ->
        Error
          "Invalid timestamp. Please specify timestamp in \"%Y-%m-%d \
           %H:%M:%S%z\". For example, \"2019-01-30 12:00:00-0800\" for \
           UTC-08:00 timezone"

  let genesis_timestamp_to_string time =
    Int64.to_float time |> Time.Span.of_ms |> Time.of_span_since_epoch
    |> Time.to_string_iso8601_basic ~zone:(Time.Zone.of_utc_offset ~hours:(-8))
end

include Helpers

(*Protocol constants required for consensus and snarks. Consensus constants is generated using these*)
module Protocol = struct
  module Poly = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type ('length, 'delta, 'genesis_state_timestamp) t =
              ( 'length
              , 'delta
              , 'genesis_state_timestamp )
              Mina_wire_types.Genesis_constants.Protocol.Poly.V1.t =
          { k : 'length
          ; slots_per_epoch : 'length
          ; slots_per_sub_window : 'length
          ; grace_period_slots : 'length
          ; delta : 'delta
          ; genesis_state_timestamp : 'genesis_state_timestamp
          }
        [@@deriving equal, ord, hash, sexp, yojson, hlist, fields]
      end
    end]
  end

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = (int, int, (Int64.t[@version_asserted])) Poly.Stable.V1.t
      [@@deriving equal, ord, hash]

      let to_latest = Fn.id

      let to_yojson (t : t) =
        `Assoc
          [ ("k", `Int t.k)
          ; ("slots_per_epoch", `Int t.slots_per_epoch)
          ; ("slots_per_sub_window", `Int t.slots_per_sub_window)
          ; ("grace_period_slots", `Int t.grace_period_slots)
          ; ("delta", `Int t.delta)
          ; ( "genesis_state_timestamp"
            , `String
                (Time.to_string_abs
                   (Time.of_span_since_epoch
                      (Time.Span.of_ms
                         (Int64.to_float t.genesis_state_timestamp) ) )
                   ~zone:Time.Zone.utc ) )
          ]

      let of_yojson = function
        | `Assoc
            [ ("k", `Int k)
            ; ("slots_per_epoch", `Int slots_per_epoch)
            ; ("slots_per_sub_window", `Int slots_per_sub_window)
            ; ("grace_period_slots", `Int grace_period_slots)
            ; ("delta", `Int delta)
            ; ("genesis_state_timestamp", `String time_str)
            ] -> (
            match validate_time time_str with
            | Ok genesis_state_timestamp ->
                Ok
                  { Poly.k
                  ; slots_per_epoch
                  ; slots_per_sub_window
                  ; grace_period_slots
                  ; delta
                  ; genesis_state_timestamp
                  }
            | Error e ->
                Error (sprintf !"Genesis_constants.Protocol.of_yojson: %s" e) )
        | _ ->
            Error "Genesis_constants.Protocol.of_yojson: unexpected JSON"

      let t_of_sexp _ = failwith "t_of_sexp: not implemented"

      let sexp_of_t (t : t) =
        let module T = struct
          type t = (int, int, string) Poly.Stable.V1.t [@@deriving sexp]
        end in
        let t' : T.t =
          { k = t.k
          ; delta = t.delta
          ; slots_per_epoch = t.slots_per_epoch
          ; slots_per_sub_window = t.slots_per_sub_window
          ; grace_period_slots = t.grace_period_slots
          ; genesis_state_timestamp =
              Time.to_string_abs
                (Time.of_span_since_epoch
                   (Time.Span.of_ms (Int64.to_float t.genesis_state_timestamp)) )
                ~zone:Time.Zone.utc
          }
        in
        T.sexp_of_t t'
    end
  end]

  [%%define_locally Stable.Latest.(to_yojson)]
end

module T = struct
  (* bin_io is for printing chain id inputs *)
  type t =
    { protocol : Protocol.Stable.Latest.t
    ; txpool_max_size : int
    ; num_accounts : int option
    ; zkapp_proof_update_cost : float
    ; zkapp_signed_single_update_cost : float
    ; zkapp_signed_pair_update_cost : float
    ; zkapp_transaction_cost_limit : float
    ; max_event_elements : int
    ; max_action_elements : int
    ; zkapp_cmd_limit_hardcap : int
    ; minimum_user_command_fee : Currency.Fee.Stable.Latest.t
    }
  [@@deriving to_yojson, sexp_of, bin_io_unversioned]

  let hash (t : t) =
    let str =
      ( List.map
          (* TODO: *)
          [ t.protocol.k
          ; t.protocol.slots_per_epoch
          ; t.protocol.slots_per_sub_window
          ; t.protocol.delta
          ; t.txpool_max_size
          ]
          ~f:Int.to_string
      |> String.concat ~sep:"" )
      ^ Time.to_string_abs ~zone:Time.Zone.utc
          (Time.of_span_since_epoch
             (Time.Span.of_ms
                (Int64.to_float t.protocol.genesis_state_timestamp) ) )
    in
    Blake2.digest_string str |> Blake2.to_hex
end

include T

module type S = sig
  module Proof_level : sig
    include module type of Proof_level with type t = Proof_level.t

    val t : t
  end

  module Fork_constants = Fork_constants

  module Constraint_constants : sig
    include
      module type of Constraint_constants with type t = Constraint_constants.t

    val t : t
  end

  val genesis_timestamp_of_string : string -> Time.t

  val of_time : Time.t -> int64

  val to_time : int64 -> Time.t

  val validate_time : string option -> (int64, string) result

  val genesis_timestamp_to_string : int64 -> string

  module Protocol = Protocol

  include module type of T with type t = T.t

  val genesis_state_timestamp_string : string

  val k : int

  val slots_per_epoch : int

  val slots_per_sub_window : int

  val grace_period_slots : int

  val delta : int

  val pool_max_size : int

  val t : t
end

module Make (Node_config : Node_config_intf.S) : S = struct
  module Proof_level = struct
    include Proof_level

    let t = of_string Node_config.proof_level
  end

  module Fork_constants = Fork_constants

  (** Constants that affect the constraint systems for proofs (and thus also key
      generation).

      Care must be taken to ensure that these match against the proving/
      verification keys when [proof_level=Full], otherwise generated proofs will
      be invalid.
  *)
  module Constraint_constants = struct
    include Constraint_constants

    (* Generate the compile-time constraint constants, using a signature to hide
       the optcomp constants that we import.
    *)
    include (
      struct
        (** All the proofs before the last [work_delay] blocks must be
            completed to add transactions. [work_delay] is the minimum number
            of blocks and will increase if the throughput is less.
            - If [work_delay = 0], all the work that was added to the scan
              state in the previous block is expected to be completed and
              included in the current block if any transactions/coinbase are to
              be included.
            - [work_delay >= 1] means that there's at least two block times for
              completing the proofs.
        *)

        let transaction_capacity_log_2 =
          match
            ( Node_config.scan_state_with_tps_goal
            , Node_config.scan_state_tps_goal_x10 )
          with
          | true, Some tps_goal_x10 ->
              let max_coinbases = 2 in

              (* block_window_duration is in milliseconds, so divide by 1000 divide
                 by 10 again because we have tps * 10
              *)
              let max_user_commands_per_block =
                tps_goal_x10 * Node_config.block_window_duration / (1000 * 10)
              in

              (* Log of the capacity of transactions per transition.
                    - 1 will only work if we don't have prover fees.
                    - 2 will work with prover fees, but not if we want a transaction
                      included in every block.
                    - At least 3 ensures a transaction per block and the staged-ledger
                      unit tests pass.
              *)
              1
              + Core_kernel.Int.ceil_log2
                  (max_user_commands_per_block + max_coinbases)
          | _ -> (
              match Node_config.scan_state_transaction_capacity_log_2 with
              | Some a ->
                  a
              | None ->
                  failwith
                    "scan_state_transaction_capacity_log_2 must be set if \
                     scan_state_with_tps_goal is false" )

        let supercharged_coinbase_factor =
          Node_config.supercharged_coinbase_factor

        let pending_coinbase_depth =
          Core_kernel.Int.ceil_log2
            ( (transaction_capacity_log_2 + 1)
              * (Node_config.scan_state_work_delay + 1)
            + 1 )

        let t =
          { sub_windows_per_window = Node_config.sub_windows_per_window
          ; ledger_depth = Node_config.ledger_depth
          ; work_delay = Node_config.scan_state_work_delay
          ; block_window_duration_ms = Node_config.block_window_duration
          ; transaction_capacity_log_2
          ; pending_coinbase_depth
          ; coinbase_amount =
              Currency.Amount.of_mina_string_exn Node_config.coinbase
          ; supercharged_coinbase_factor
          ; account_creation_fee =
              Currency.Fee.of_mina_string_exn
                Node_config.account_creation_fee_int
          ; fork = None
          }
      end :
        sig
          val t : t
        end )
  end

  include Helpers
  module Protocol = Protocol
  include T

  let genesis_state_timestamp_string = Node_config.genesis_state_timestamp

  let k = Node_config.k

  let slots_per_epoch = Node_config.slots_per_epoch

  let slots_per_sub_window = Node_config.slots_per_sub_window

  let grace_period_slots = Node_config.grace_period_slots

  let delta = Node_config.delta

  let pool_max_size = Node_config.pool_max_size

  let t : t =
    { protocol =
        { k
        ; slots_per_epoch
        ; slots_per_sub_window
        ; grace_period_slots
        ; delta
        ; genesis_state_timestamp =
            genesis_timestamp_of_string genesis_state_timestamp_string
            |> of_time
        }
    ; txpool_max_size = pool_max_size
    ; num_accounts = None
    ; zkapp_proof_update_cost = Node_config.zkapp_proof_update_cost
    ; zkapp_signed_single_update_cost =
        Node_config.zkapp_signed_single_update_cost
    ; zkapp_signed_pair_update_cost = Node_config.zkapp_signed_pair_update_cost
    ; zkapp_transaction_cost_limit = Node_config.zkapp_transaction_cost_limit
    ; max_event_elements = Node_config.max_event_elements
    ; max_action_elements = Node_config.max_action_elements
    ; zkapp_cmd_limit_hardcap = Node_config.zkapp_cmd_limit_hardcap
    ; minimum_user_command_fee =
        Currency.Fee.of_mina_string_exn Node_config.minimum_user_command_fee
    }
end

module For_unit_tests = Make (Node_config_for_unit_tests)
