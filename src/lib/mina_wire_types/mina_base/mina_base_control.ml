module V2 = struct
  type t =
    | Proof of Pickles.Side_loaded.Proof.V2.t
    | Signature of Mina_base_signature.V1.t
    | None_given
end
