type t =
  | Set_delegate of
      { delegator : Public_key.compressed
      ; new_delegate : Public_key.compressed
      }
