(** Visualizable_ledger shows a subgraph of a merkle_ledger using Graphviz *)

module Make (Inputs : Graphviz_intf.Inputs_intf) :
  Graphviz_intf.S
    with type addr := Inputs.Location.Addr.t
     and type ledger := Inputs.Ledger.t
