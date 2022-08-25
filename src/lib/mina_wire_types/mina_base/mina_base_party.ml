module Body = struct
  module Fee_payer = struct
    module V1 = struct
      type t =
        { public_key : Public_key.Compressed.V1.t
        ; fee : Currency.Fee.V1.t
        ; valid_until : Mina_numbers.Global_slot.V1.t option
        ; nonce : Mina_numbers.Account_nonce.V1.t
        }
    end
  end
end

module Fee_payer = struct
  module V1 = struct
    type t =
      { body : Body.Fee_payer.V1.t; authorization : Mina_base_signature.V1.t }
  end
end
