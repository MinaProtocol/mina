val proof_string : 'a Pickles_types.Nat.t -> Core_kernel__.Import.string

val blockchain_proof_string : Core_kernel__.Import.string

val transaction_proof_string : Core_kernel__.Import.string

val str : loc:Ppxlib__.Location.t -> Ppxlib.Parsetree.structure_item list

val main : unit -> unit
