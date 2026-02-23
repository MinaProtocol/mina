open Core_kernel
module Wire_types = Mina_wire_types.Mina_base.Call_stack_digest

module Make_sig (A : Wire_types.Types.S) = struct
  module type S = Call_stack_digest_intf.Full with type Stable.V1.t = A.V1.t
end

module Make_str (A : Wire_types.Concrete) = struct
  [%%versioned
  module Stable = struct
    module V1 = struct
      type t = Kimchi_backend.Pasta.Basic.Fp.Stable.V1.t
      [@@deriving sexp, compare, equal, hash, yojson]

      let to_latest = Fn.id
    end
  end]

  open Pickles.Impls.Step

  let cons (h : Stack_frame.Digest.t) (t : t) : t =
    Random_oracle.hash ~init:Hash_prefix_states.account_update_stack_frame_cons
      [| (h :> Field.Constant.t); t |]

  let empty = Field.Constant.zero

  let gen = Field.Constant.gen

  module Checked = struct
    include Field

    let cons (h : Stack_frame.Digest.Checked.t) (t : t) : t =
      Random_oracle.Checked.hash
        ~init:Hash_prefix_states.account_update_stack_frame_cons
        [| (h :> Field.t); t |]
  end

  let constant = Field.constant

  let typ = Field.typ
end

include Wire_types.Make (Make_sig) (Make_str)
