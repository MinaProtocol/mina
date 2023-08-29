include
  Diff_intf.Full
    with type 'a At_most_two.t =
      'a Mina_wire_types.Staged_ledger_diff.At_most_two.V1.t
     and type 'a At_most_two.Stable.V1.t =
      'a Mina_wire_types.Staged_ledger_diff.At_most_two.V1.t
     and type ('a, 'b) Pre_diff_two.Stable.V2.t =
      ('a, 'b) Mina_wire_types.Staged_ledger_diff.Pre_diff_two.V2.t
     and type Pre_diff_with_at_most_two_coinbase.Stable.V2.t =
      Mina_wire_types.Staged_ledger_diff.Pre_diff_with_at_most_two_coinbase.V2.t
     and type 'a At_most_one.t =
      'a Mina_wire_types.Staged_ledger_diff.At_most_one.V1.t
     and type ('a, 'b) Pre_diff_one.Stable.V2.t =
      ('a, 'b) Mina_wire_types.Staged_ledger_diff.Pre_diff_one.V2.t
     and type Pre_diff_with_at_most_one_coinbase.Stable.V2.t =
      Mina_wire_types.Staged_ledger_diff.Pre_diff_with_at_most_one_coinbase.V2.t
     and type t = Mina_wire_types.Staged_ledger_diff.V2.t
     and type Stable.V2.t = Mina_wire_types.Staged_ledger_diff.V2.t
