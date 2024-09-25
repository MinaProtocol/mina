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
  module Inputs = struct
    type t =
      { state_hash : string
      ; blockchain_length : int
      ; global_slot_since_genesis : int
      }
  end

  type t =
    { state_hash : Pickles.Backend.Tick.Field.Stable.Latest.t
    ; blockchain_length : Mina_numbers.Length.Stable.Latest.t
    ; global_slot_since_genesis :
        Mina_numbers.Global_slot_since_genesis.Stable.Latest.t
    }
  [@@deriving bin_io_unversioned, sexp, equal, compare, yojson]

  let make (inputs : Inputs.t) : t =
    { state_hash = Pickles.Backend.Tick.Field.of_string inputs.state_hash
    ; blockchain_length = Mina_numbers.Length.of_int inputs.blockchain_length
    ; global_slot_since_genesis =
        Mina_numbers.Global_slot_since_genesis.of_int
          inputs.global_slot_since_genesis
    }
end

module Constraint_constants = struct
  module Inputs = struct
    type t =
      { scan_state_with_tps_goal : bool
      ; scan_state_tps_goal_x10 : int option
      ; block_window_duration : int
      ; scan_state_transaction_capacity_log_2 : int option
      ; supercharged_coinbase_factor : int
      ; scan_state_work_delay : int
      ; coinbase : string
      ; account_creation_fee_int : string
      ; ledger_depth : int
      ; sub_windows_per_window : int
      ; fork : Fork_constants.Inputs.t option
      }
  end

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

  let make (inputs : Inputs.t) : t =
    (* All the proofs before the last [work_delay] blocks must be
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
        (inputs.scan_state_with_tps_goal, inputs.scan_state_tps_goal_x10)
      with
      | true, Some tps_goal_x10 ->
          let max_coinbases = 2 in

          (* block_window_duration is in milliseconds, so divide by 1000 divide
             by 10 again because we have tps * 10
          *)
          let max_user_commands_per_block =
            tps_goal_x10 * inputs.block_window_duration / (1000 * 10)
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
          match inputs.scan_state_transaction_capacity_log_2 with
          | Some a ->
              a
          | None ->
              failwith
                "scan_state_transaction_capacity_log_2 must be set if \
                 scan_state_with_tps_goal is false" )
    in
    let supercharged_coinbase_factor = inputs.supercharged_coinbase_factor in

    let pending_coinbase_depth =
      Core_kernel.Int.ceil_log2
        ( ((transaction_capacity_log_2 + 1) * (inputs.scan_state_work_delay + 1))
        + 1 )
    in

    { sub_windows_per_window = inputs.sub_windows_per_window
    ; ledger_depth = inputs.ledger_depth
    ; work_delay = inputs.scan_state_work_delay
    ; block_window_duration_ms = inputs.block_window_duration
    ; transaction_capacity_log_2
    ; pending_coinbase_depth
    ; coinbase_amount = Currency.Amount.of_mina_string_exn inputs.coinbase
    ; supercharged_coinbase_factor
    ; account_creation_fee =
        Currency.Fee.of_mina_string_exn inputs.account_creation_fee_int
    ; fork = Option.map ~f:Fork_constants.make inputs.fork
    }

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
              { blockchain_length = Mina_numbers.Length.to_int blockchain_length
              ; state_hash = Pickles.Backend.Tick.Field.to_string state_hash
              ; global_slot_since_genesis =
                  Mina_numbers.Global_slot_since_genesis.to_int
                    global_slot_since_genesis
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
  module Inputs = struct
    type t =
      { genesis_state_timestamp : string
      ; k : int
      ; slots_per_epoch : int
      ; slots_per_sub_window : int
      ; grace_period_slots : int
      ; delta : int
      ; pool_max_size : int
      ; num_accounts : int option
      ; zkapp_proof_update_cost : float
      ; zkapp_signed_single_update_cost : float
      ; zkapp_signed_pair_update_cost : float
      ; zkapp_transaction_cost_limit : float
      ; max_event_elements : int
      ; max_action_elements : int
      ; zkapp_cmd_limit_hardcap : int
      ; minimum_user_command_fee : string
      }
  end

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

  let make (inputs : Inputs.t) : t =
    { protocol =
        { k = inputs.k
        ; slots_per_epoch = inputs.slots_per_epoch
        ; slots_per_sub_window = inputs.slots_per_sub_window
        ; grace_period_slots = inputs.grace_period_slots
        ; delta = inputs.delta
        ; genesis_state_timestamp =
            genesis_timestamp_of_string inputs.genesis_state_timestamp
            |> of_time
        }
    ; txpool_max_size = inputs.pool_max_size
    ; num_accounts = inputs.num_accounts
    ; zkapp_proof_update_cost = inputs.zkapp_proof_update_cost
    ; zkapp_signed_single_update_cost = inputs.zkapp_signed_single_update_cost
    ; zkapp_signed_pair_update_cost = inputs.zkapp_signed_pair_update_cost
    ; zkapp_transaction_cost_limit = inputs.zkapp_transaction_cost_limit
    ; max_event_elements = inputs.max_event_elements
    ; max_action_elements = inputs.max_action_elements
    ; zkapp_cmd_limit_hardcap = inputs.zkapp_cmd_limit_hardcap
    ; minimum_user_command_fee =
        Currency.Fee.of_mina_string_exn inputs.minimum_user_command_fee
    }

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

module For_unit_tests = struct
  let inputs =
    { T.Inputs.genesis_state_timestamp =
        Node_config_for_unit_tests.genesis_state_timestamp
    ; k = Node_config_for_unit_tests.k
    ; slots_per_epoch = Node_config_for_unit_tests.slots_per_epoch
    ; slots_per_sub_window = Node_config_for_unit_tests.slots_per_sub_window
    ; grace_period_slots = Node_config_for_unit_tests.grace_period_slots
    ; delta = Node_config_for_unit_tests.delta
    ; pool_max_size = Node_config_for_unit_tests.pool_max_size
    ; num_accounts = None
    ; zkapp_proof_update_cost =
        Node_config_for_unit_tests.zkapp_proof_update_cost
    ; zkapp_signed_single_update_cost =
        Node_config_for_unit_tests.zkapp_signed_single_update_cost
    ; zkapp_signed_pair_update_cost =
        Node_config_for_unit_tests.zkapp_signed_pair_update_cost
    ; zkapp_transaction_cost_limit =
        Node_config_for_unit_tests.zkapp_transaction_cost_limit
    ; max_event_elements = Node_config_for_unit_tests.max_event_elements
    ; max_action_elements = Node_config_for_unit_tests.max_action_elements
    ; zkapp_cmd_limit_hardcap =
        Node_config_for_unit_tests.zkapp_cmd_limit_hardcap
    ; minimum_user_command_fee =
        Node_config_for_unit_tests.minimum_user_command_fee
    }

  let t = T.make inputs

  module Constraint_constants = struct
    let inputs =
      { Constraint_constants.Inputs.scan_state_with_tps_goal =
          Node_config_for_unit_tests.scan_state_with_tps_goal
      ; scan_state_tps_goal_x10 =
          Node_config_for_unit_tests.scan_state_tps_goal_x10
      ; block_window_duration = Node_config_for_unit_tests.block_window_duration
      ; scan_state_transaction_capacity_log_2 =
          Node_config_for_unit_tests.scan_state_transaction_capacity_log_2
      ; supercharged_coinbase_factor =
          Node_config_for_unit_tests.supercharged_coinbase_factor
      ; scan_state_work_delay = Node_config_for_unit_tests.scan_state_work_delay
      ; coinbase = Node_config_for_unit_tests.coinbase
      ; account_creation_fee_int =
          Node_config_for_unit_tests.account_creation_fee_int
      ; ledger_depth = Node_config_for_unit_tests.ledger_depth
      ; sub_windows_per_window =
          Node_config_for_unit_tests.sub_windows_per_window
      ; fork = None
      }

    let t = Constraint_constants.make inputs
  end

  module Proof_level = struct
    let inputs = Node_config_for_unit_tests.proof_level

    let t = Proof_level.of_string inputs
  end

  let genesis_state_timestamp_string =
    Node_config_for_unit_tests.genesis_state_timestamp

  let k = Node_config_for_unit_tests.k

  let slots_per_epoch = Node_config_for_unit_tests.slots_per_epoch

  let slots_per_sub_window = Node_config_for_unit_tests.slots_per_sub_window

  let grace_period_slots = Node_config_for_unit_tests.grace_period_slots

  let delta = Node_config_for_unit_tests.delta

  let pool_max_size = Node_config_for_unit_tests.pool_max_size
end
