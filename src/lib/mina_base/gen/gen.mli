val keypairs : Signature_lib.Keypair.t list

val expr : loc:Ppxlib__.Location.t -> Ppxlib.Parsetree.expression

val structure : loc:Ppxlib__.Location.t -> Ppxlib.Parsetree.structure_item list

val json :
  [> `List of [> `Assoc of (string * [> `String of string ]) list ] list ]

val main : unit -> 'a
