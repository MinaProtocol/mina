type curvetype = (* pallas *) string [@@deriving yojson, show]

type signaturetype = (* schnorr_poseidon *) string [@@deriving yojson, show]

type coinaction = () [@@deriving yojson, show, eq]

type blockeventtype = () [@@deriving yojson, show, eq]

type exemptiontype = () [@@deriving yojson, show, eq]

type operator = () [@@deriving yojson, show, eq]
