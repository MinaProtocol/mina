(*Types coresponding to the result of graphql queries*)

(*List of completed work from Graphql_client.Snark_pool*)
module Completed_works = struct
  module Work = struct
    type t =
      { work_ids: int list
      ; fee: Currency.Fee.Stable.V1.t
      ; prover: Signature_lib.Public_key.Compressed.t }
    [@@deriving yojson]
  end

  type t = Work.t list [@@deriving yojson]
end
