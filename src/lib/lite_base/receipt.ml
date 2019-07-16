module Chain_hash = struct
  type t = Lite_params.Tock.Fq.t [@@deriving bin_io, sexp, to_yojson, eq]

  let fold = Lite_params.Tock.Fq.fold
end
