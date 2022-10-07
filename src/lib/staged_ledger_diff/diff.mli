include
  Diff_intf.Full
    with type 'a At_most_two.t =
      'a Mina_wire_types.Staged_ledger_diff.At_most_two.V1.t
     and type 'a At_most_two.Stable.V1.t =
      'a Mina_wire_types.Staged_ledger_diff.At_most_two.V1.t
