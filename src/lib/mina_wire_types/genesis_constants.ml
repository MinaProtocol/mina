module Protocol = struct
  module Poly = struct
    module V2 = struct
      type ('length, 'delta, 'genesis_state_timestamp, 'timespan) t =
        { k : 'length
        ; slots_per_epoch : 'length
        ; slots_per_sub_window : 'length
        ; grace_period_slots : 'length
        ; delta : 'delta
        ; genesis_state_timestamp : 'genesis_state_timestamp
        ; block_window_duration_ms : 'timespan
        }
    end

    module V1 = struct
      type ('length, 'delta, 'genesis_state_timestamp) t =
        { k : 'length
        ; slots_per_epoch : 'length
        ; slots_per_sub_window : 'length
        ; grace_period_slots : 'length
        ; delta : 'delta
        ; genesis_state_timestamp : 'genesis_state_timestamp
        }
    end
  end
end
