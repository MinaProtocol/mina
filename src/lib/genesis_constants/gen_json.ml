open Core_kernel

(* TODO: Delete this module and construct these directly at the top level*)
module Compiled : sig
  module Inputs : sig
    type t =
      { genesis : Genesis_constants.T.Inputs.t
      ; constraint_constants : Genesis_constants.Constraint_constants.Inputs.t
      }

    val t : t

    val to_yojson : t -> Yojson.Safe.t
  end
end = struct
  module Inputs = struct
    type t =
      { genesis : Genesis_constants.T.Inputs.t
      ; constraint_constants : Genesis_constants.Constraint_constants.Inputs.t
      }
    [@@deriving to_yojson]

    let genesis =
      { Genesis_constants.T.Inputs.genesis_state_timestamp =
          Node_config.genesis_state_timestamp
      ; k = Node_config.k
      ; slots_per_epoch = Node_config.slots_per_epoch
      ; slots_per_sub_window = Node_config.slots_per_sub_window
      ; grace_period_slots = Node_config.grace_period_slots
      ; delta = Node_config.delta
      ; pool_max_size = Node_config.pool_max_size
      ; num_accounts = None
      ; zkapp_proof_update_cost = Node_config.zkapp_proof_update_cost
      ; zkapp_signed_single_update_cost =
          Node_config.zkapp_signed_single_update_cost
      ; zkapp_signed_pair_update_cost =
          Node_config.zkapp_signed_pair_update_cost
      ; zkapp_transaction_cost_limit = Node_config.zkapp_transaction_cost_limit
      ; max_event_elements = Node_config.max_event_elements
      ; max_action_elements = Node_config.max_action_elements
      ; zkapp_cmd_limit_hardcap = Node_config.zkapp_cmd_limit_hardcap
      ; minimum_user_command_fee = Node_config.minimum_user_command_fee
      }

    let constraint_constants =
      { Genesis_constants.Constraint_constants.Inputs.scan_state_with_tps_goal =
          Node_config.scan_state_with_tps_goal
      ; scan_state_tps_goal_x10 = Node_config.scan_state_tps_goal_x10
      ; block_window_duration = Node_config.block_window_duration
      ; scan_state_transaction_capacity_log_2 =
          Node_config.scan_state_transaction_capacity_log_2
      ; supercharged_coinbase_factor = Node_config.supercharged_coinbase_factor
      ; scan_state_work_delay = Node_config.scan_state_work_delay
      ; coinbase = Node_config.coinbase
      ; account_creation_fee_int = Node_config.account_creation_fee_int
      ; ledger_depth = Node_config.ledger_depth
      ; sub_windows_per_window = Node_config.sub_windows_per_window
      ; fork = None
      ; proof_level = Node_config.proof_level
      }

    let t = { genesis; constraint_constants }
  end
end

let () =
  let json = Compiled.Inputs.to_yojson Compiled.Inputs.t in
  let json_str = Yojson.Safe.pretty_to_string json in
  let oc = Out_channel.create "genesis_constants.json" in
  Out_channel.output_string oc json_str ;
  Out_channel.close oc
