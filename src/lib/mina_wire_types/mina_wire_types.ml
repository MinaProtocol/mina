module Currency = struct
  include Currency
  include M
end

module Snark_params = Snark_params
module Public_key = Public_key

module Mina_base = struct
  module Signed_command_payload = Mina_base_signed_command_payload
end
