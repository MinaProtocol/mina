type curvetype = (* tweedle *) string [@@deriving yojson, show]

type signaturetype = (* schnorr *) string [@@deriving yojson, show]

type coinaction = () [@@deriving yojson, show, eq]
