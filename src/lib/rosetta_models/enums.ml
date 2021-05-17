type curvetype = (* pallas *) string [@@deriving yojson, show]

type signaturetype = (* schnorr_poseidon *) string [@@deriving yojson, show]

type coinaction = unit [@@deriving yojson, show, eq]

type blockeventtype = unit [@@deriving yojson, show, eq]

type exemptiontype = unit [@@deriving yojson, show, eq]

type operator = unit [@@deriving yojson, show, eq]
