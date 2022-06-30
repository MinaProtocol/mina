type t =
  | Set_delegate of
      { delegator : Public_key.Compressed.t
      ; new_delegate : Public_key.Compressed.t
      }
