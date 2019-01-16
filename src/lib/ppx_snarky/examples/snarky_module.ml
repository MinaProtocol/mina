module Type = struct
  [%%snarky_module
  (** The [polydef] extension defines a new polymorphic type. *)
  let%polydef polymorphic = {a= A; b= B; c= C; d= A; e= [A.t; A.Something.t]}

  (** The [polyfields] extension derives accessors for the given polymorphic type. *)[%%polyfields
  polymorphic]

  (** The [poly] extension defines a type based on a [polydef]-ed type, localising the types to the current module if necessary. *)[%%poly
  type t = polymorphic]

  (** The [snarkytyp] extension generates a [Typ.t] named as given.
    NOTE: The [typ]s of the fields' modules are assumed to have the same name, and to live in the toplevel module. *)[%%snarkytyp
  (typ : polymorphic Typ.t)]

  module Var = struct
    [%%poly
    type t = polymorphic]

    (** The [polyfold] extension creates a function which folds over the fields. The function to the right of [=] is used for the folding itself, and a function of the same name from each field's module is applied to the fields. *)
    let%polyfold f x = ( + )
  end]
end

module Type2 = struct
  [%%snarky_module
  let%polydef polymorphic =
    { length= [Nat; Nat.Snark]
    ; timestamp= [Snarky.Time.T; Snarky.Time.Checked]
    ; previous_hash= (Hash.T, Hash.Snarkable)
    ; next_hash= Hash
    ; new_hash= [|Hash.New.T; Hash.Snarkable|] }

  [%%polyfields
  polymorphic]

  module T = struct
    [%%poly type t = polymorphic]
  end

  include T

  [%%snarkytyp
  (typ : polymorphic Typ.t)]

  module Snarkable = struct
    [%%poly
    type t = polymorphic]

    let%polyfold length_in_bits t = Pervasives.( + )

    let%polyfold fold t = Fold_lib.( +> )

    let%polyfold var_to_triples t = Pervasives.( @ )

    let%polyfold length_in_triples t = Pervasives.( + )

    let%polyfold something_else t x y = x + y
  end]
end
