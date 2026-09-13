module V1 = struct
  type t =
    ( Pickles.Side_loaded.Verification_key.V3.t
    , Snark_params.Tick.Field.t )
    With_hash.t
end
