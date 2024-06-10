(** Visualizable_ledger shows a subgraph of a merkle_ledger using Graphviz *)

module Make (Inputs : Intf.Graphviz.I) :
  Intf.Graphviz.S
    with type addr := Inputs.Location.Addr.t
     and type ledger := Inputs.Ledger.t
