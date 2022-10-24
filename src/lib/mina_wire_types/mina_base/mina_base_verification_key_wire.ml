module V1 = struct
  type t =
    ( Pickles.Side_loaded.Verification_key.V2.t
    , Snark_params.Step.Field.t )
    With_hash.t
end
