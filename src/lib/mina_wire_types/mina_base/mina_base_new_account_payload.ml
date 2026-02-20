module V1 = struct
  type t =
    { token_id : Mina_base_token_id.V2.t
    ; token_owner_pk : Public_key.Compressed.V1.t
    ; receiver_pk : Public_key.Compressed.V1.t
    ; account_disabled : bool
    }
end
