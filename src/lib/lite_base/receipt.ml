module Chain_hash = struct
  type t = Crypto_params.Tock.Fq.t [@@deriving bin_io, sexp, to_yojson, eq]

  let fold = Crypto_params.Tock.Fq.fold
end
