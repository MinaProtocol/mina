[%%import
"../../config.mlh"]

module Constants = Constants
include Intf

[%%if
consensus_mechanism = "proof_of_signature"]

include Proof_of_signature

[%%elif
consensus_mechanism = "proof_of_stake"]

include Proof_of_stake

[%%else]

[%%show
consesus_mechanism]

[%%error
"invalid value for \"consensus_mechanism\""]

[%%endif]
