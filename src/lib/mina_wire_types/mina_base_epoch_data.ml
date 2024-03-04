module Poly = struct
  module V1 = struct
    type ( 'epoch_ledger
         , 'epoch_seed
         , 'start_checkpoint
         , 'lock_checkpoint
         , 'length )
         t =
      { ledger : 'epoch_ledger
      ; seed : 'epoch_seed
      ; start_checkpoint : 'start_checkpoint
      ; lock_checkpoint : 'lock_checkpoint
      ; epoch_length : 'length
      }
  end
end
