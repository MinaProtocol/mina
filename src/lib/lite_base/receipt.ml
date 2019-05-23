module Chain_hash = struct
  type t = Lite_params.Tock.Fq.t [@@deriving bin_io, sexp, eq]

  let fold = Lite_params.Tock.Fq.fold
end
