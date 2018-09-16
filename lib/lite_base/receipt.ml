module Chain_hash = struct
  type t = Snarkette.Mnt6.Fq.t [@@deriving bin_io, sexp, eq]

  let fold = Snarkette.Mnt6.Fq.fold
end
