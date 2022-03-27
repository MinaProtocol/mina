module Impl = Pickles.Impls.Step.Internal_Basic
module Group = Pickles.Backend.Tick.Inner_curve

val group_map_params : Pickles.Backend.Tick.Field.t Group_map.Params.t

val group_map_params_structure :
  loc:Ppxlib__.Location.t -> Ppxlib.Parsetree.structure_item list

val generate_ml_file :
  Base.string -> (loc:Ppxlib.Location.t -> Ppxlib.Parsetree.structure) -> unit
