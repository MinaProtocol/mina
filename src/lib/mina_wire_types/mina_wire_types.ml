module Currency = struct
  include Currency
  include M
end

module Snark_params = Snark_params
module Public_key = Public_key
module Mina_numbers = Mina_numbers

module Mina_base = struct
  module Signed_command_payload = Mina_base_signed_command_payload

  module Token_id = struct
    include Mina_base_token_id
    include M
  end
end
