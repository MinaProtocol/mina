[%%import
"/src/config.mlh"]

open Core_kernel

[%%ifdef
consensus_mechanism]

open Signature_lib

[%%else]

open Signature_lib_nonconsensus

[%%endif]

module Impl = Pickles.Impls.Step

module Payload = struct
  module Poly = struct
    [%%versioned
    module Stable = struct
      module V1 = struct
        type ('pk, 'token_id, 'nonce, 'fee) t =
          {pk: 'pk; token_id: 'token_id; nonce: 'nonce; fee: 'fee}
        [@@deriving hlist, sexp, eq, yojson, hash, compare]
      end
    end]
  end

  [%%versioned
  module Stable = struct
    module V1 = struct
      type t =
        ( Public_key.Compressed.Stable.V1.t
        , Token_id.Stable.V1.t
        , Coda_numbers.Account_nonce.Stable.V1.t
        , Currency.Fee.Stable.V1.t )
        Poly.Stable.V1.t
      [@@deriving sexp, eq, yojson, hash, compare]

      let to_latest = Fn.id
    end
  end]

  let dummy : t =
    { pk= Public_key.Compressed.empty
    ; token_id= Token_id.invalid
    ; nonce= Coda_numbers.Account_nonce.zero
    ; fee= Currency.Fee.zero }

  let to_input ({pk; token_id; nonce; fee} : t) =
    let open Random_oracle_input in
    List.reduce_exn ~f:append
      [ Public_key.Compressed.to_input pk
      ; Token_id.to_input token_id
      ; Coda_numbers.Account_nonce.to_input nonce
      ; Currency.Fee.to_input fee ]
end

[%%versioned
module Stable = struct
  module V1 = struct
    type t = {payload: Payload.Stable.V1.t; signature: Signature.Stable.V1.t}
    [@@deriving sexp, eq, yojson, hash, compare]

    let to_latest = Fn.id
  end
end]
