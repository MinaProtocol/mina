module Currency = struct
  include Currency
  include M
end

module Snark_params = Snark_params
module Public_key = Public_key

module Mina_base = struct
  module Signed_command_payload = Mina_base_signed_command_payload

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
