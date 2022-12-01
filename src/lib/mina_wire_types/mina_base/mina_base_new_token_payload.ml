module V1 = struct
  type t =
    { token_owner_pk : Public_key.Compressed.V1.t; disable_new_accounts : bool }
end
