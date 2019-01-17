module Make (Impl : Snark_intf.Basic) :
  Number_intf.S
  with type ('a, 'b) checked := ('a, 'b) Impl.Checked.t
   and type field := Impl.Field.t
   and type field_var := Impl.Field.Checked.t
   and type bool_var := Impl.Boolean.var
