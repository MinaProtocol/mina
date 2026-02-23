open Utils

(** We first define a [Types] module, with the expected final signature of this
    module (hidden types should be hidden here) *)
module Types = struct
  module type S = sig
    module Fee : V1S0

    module Amount : V1S0

    module Balance : V1S0
  end
end

(** We define a module type [Concrete], where we replace hidden types in
    {!Types.S} by their actual definition. This module will not be exported. *)
module type Concrete =
  Types.S
    with type Fee.V1.t = Unsigned.UInt64.t
     and type Amount.V1.t = Unsigned.UInt64.t
     and type Balance.V1.t = Unsigned.UInt64.t

(** Then we define the actual module [M] with its type definitions. It must be
    compatible with {!Concrete} *)
module M = struct
  module Fee = struct
    module V1 = struct
      type t = Unsigned.UInt64.t
    end
  end

  module Amount = struct
    module V1 = struct
      type t = Unsigned.UInt64.t
    end
  end

  module Balance = struct
    module V1 = struct
      type t = Amount.V1.t
    end
  end
end

(** [Local_sig] is the type of functors which receive a {!Types.S} module and
    return a complete module signature (with operations etc.) based on these
    types. It will be expected to be given by the implementation module. *)
module type Local_sig = Signature(Types).S

(** To make a full module, the implementation module will have to use [Make] and
    provide: (i) a {!Local_sig} functor to know the final signature of the
    module and (ii) a functor which takes the concrete types defined here and
    make the actual full module, adding type equalities where needed. *)
module Make
    (Signature : Local_sig) (F : functor (A : Concrete) -> Signature(A).S) =
  F (M)

(** Finally, we include our module to make the types available to everyone (they
    will be hidden in the MLI *)
include M
