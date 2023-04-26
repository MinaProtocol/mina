module V1 = struct
  type t = Set_delegate of { new_delegate : Public_key.Compressed.V1.t }
end
