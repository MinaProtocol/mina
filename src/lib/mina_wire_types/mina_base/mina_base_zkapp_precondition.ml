module Closed_interval = struct
  module V1 = struct
    type 'a t = { lower : 'a; upper : 'a }
  end
end

module Numeric = struct
  module V1 = struct
    type 'a t = 'a Closed_interval.V1.t Mina_base_zkapp_basic.Or_ignore.V1.t
  end
end

module Protocol_state = struct
  module Epoch_data = struct
    module V1 = struct
      type t =
        ( ( Mina_base_ledger_hash.V1.t Mina_base_zkapp_basic.Or_ignore.V1.t
          , Currency.Amount.V1.t Numeric.V1.t )
          Mina_base_epoch_ledger.Poly.V1.t
        , Snark_params.Tick.Field.t Mina_base_zkapp_basic.Or_ignore.V1.t
        , Data_hash_lib.State_hash.V1.t Mina_base_zkapp_basic.Or_ignore.V1.t
        , Data_hash_lib.State_hash.V1.t Mina_base_zkapp_basic.Or_ignore.V1.t
        , Mina_numbers.Length.V1.t Numeric.V1.t )
        Mina_base_epoch_data.Poly.V1.t
    end
  end
end
