open Utils

module Types = struct
  module type S = sig
    module State_stack : sig
      module V1 : sig
        type t
      end
    end

    module Stack_versioned : sig
      module V1 : sig
        type nonrec t
      end
    end
  end
end

module type Concrete = sig
  module Poly : sig
    type ('tree, 'stack_id) t =
      { tree : 'tree; pos_list : 'stack_id list; new_pos : 'stack_id }
  end

  module Stack_hash : sig
    module V1 : sig
      type t = Snark_params.Tick.Field.t
    end
  end

  module State_stack : sig
    module Poly : sig
      module V1 : sig
        type 'stack_hash t = { init : 'stack_hash; curr : 'stack_hash }
      end
    end

    module V1 : sig
      type t = Stack_hash.V1.t Poly.V1.t
    end
  end

  module Coinbase_stack : sig
    module V1 : sig
      type t = Snark_params.Tick.Field.t
    end
  end

  module Stack_versioned : sig
    module Poly : sig
      module V1 : sig
        type ('data_stack, 'state_stack) t =
          { data : 'data_stack; state : 'state_stack }
      end
    end

    module V1 : sig
      type t = (Coinbase_stack.V1.t, State_stack.V1.t) Poly.V1.t
    end
  end
end

module M = struct
  module Poly = struct
    type ('tree, 'stack_id) t =
      { tree : 'tree; pos_list : 'stack_id list; new_pos : 'stack_id }
  end

  module Stack_hash = struct
    module V1 = struct
      type t = Snark_params.Tick.Field.t
    end
  end

  module State_stack = struct
    module Poly = struct
      module V1 = struct
        type 'stack_hash t = { init : 'stack_hash; curr : 'stack_hash }
      end
    end

    module V1 = struct
      type t = Stack_hash.V1.t Poly.V1.t
    end
  end

  module Coinbase_stack = struct
    module V1 = struct
      type t = Snark_params.Tick.Field.t
    end
  end

  module Stack_versioned = struct
    module Poly = struct
      module V1 = struct
        type ('data_stack, 'state_stack) t =
          { data : 'data_stack; state : 'state_stack }
      end
    end

    module V1 = struct
      type t = (Coinbase_stack.V1.t, State_stack.V1.t) Poly.V1.t
    end
  end
end

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (F : functor (A : Concrete) -> Signature(A).S) =
  F (M)
include M
