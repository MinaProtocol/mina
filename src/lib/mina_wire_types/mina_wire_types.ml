module Currency = struct
  include Currency
  include M
end

module Snark_params = Snark_params
module Public_key = Public_key

module Mina_base = struct
  module Signed_command_payload = Mina_base_signed_command_payload
  module Signed_command = Mina_base_signed_command
  module Payment_payload = Mina_base_payment_payload
  module Stake_delegation = Mina_base_stake_delegation
  module New_token_payload = Mina_base_new_token_payload
  module New_account_payload = Mina_base_new_account_payload
  module Minting_payload = Mina_base_minting_payload
  module Signature = Mina_base_signature

  module Signed_command_memo = struct
    include Mina_base_signed_command_memo
    include M
  end

  module Token_id = struct
    include Mina_base_token_id
    include M
  end
end

module Mina_numbers = struct
  module Account_nonce = struct
    include Mina_numbers.Account_nonce
    include M
  end

  module Global_slot = struct
    include Mina_numbers.Global_slot
    include M
  end
end
