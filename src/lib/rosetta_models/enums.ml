type curvetype = (* pallas *) string [@@deriving yojson, show, eq]

type signaturetype = (* schnorr_poseidon *) string [@@deriving yojson, show, eq]

type coinaction = Coin_action [@@deriving yojson, show, eq]

type blockeventtype = Block_event_type [@@deriving yojson, show, eq]

type exemptiontype = Exemption_type [@@deriving yojson, show, eq]

type operator = Operator [@@deriving yojson, show, eq]
