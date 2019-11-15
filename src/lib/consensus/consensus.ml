[%%import
"../../config.mlh"]

module Intf = Intf
module Global_slot = Global_slot

[%%if
consensus_mechanism = "proof_of_stake"]

include Proof_of_stake

[%%else]

[%%show
consesus_mechanism]

[%%error
"invalid value for \"consensus_mechanism\""]

[%%endif]
