type t [@@deriving sexp, yojson]

module Stable : sig
  module V1 : sig
    type nonrec t = t [@@deriving sexp]
  end
end

val encrypt : password:Bytes.t -> plaintext:Bytes.t -> t

val decrypt : password:Bytes.t -> t -> Bytes.t Core.Or_error.t
