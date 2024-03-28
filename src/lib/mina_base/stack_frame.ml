open Core_kernel

[%%versioned
module Stable = struct
  module V1 = struct
    type ('caller, 'zkapp_command) t =
      { caller : 'caller; caller_caller : 'caller; calls : 'zkapp_command }
    [@@deriving make, fields, sexp, yojson]
  end
end]

type value =
  ( Token_id.t
  , ( Account_update.t
    , Zkapp_command.Digest.Account_update.t
    , Zkapp_command.Digest.Forest.t )
    Zkapp_command.Call_forest.t )
  t

type ('caller, 'zkapp_command) frame = ('caller, 'zkapp_command) t

let empty : value =
  { caller = Token_id.default; caller_caller = Token_id.default; calls = [] }

module type Stack_frame_digest_intf = sig
  include Digest_intf.S

  val create :
       ( Token_id.t
       , ( 'p
         , Zkapp_command.Digest.Account_update.t
         , Zkapp_command.Digest.Forest.t )
         Zkapp_command.Call_forest.t )
       frame
    -> t

  val gen : t Quickcheck.Generator.t

  open Pickles.Impls.Step

  module Checked : sig
    include Digest_intf.S_checked

    val create :
         hash_zkapp_command:
           ('zkapp_command -> Zkapp_command.Digest.Forest.Checked.t)
      -> (Token_id.Checked.t, 'zkapp_command) frame
      -> t
  end

  val typ : (Checked.t, t) Typ.t
end

module Wire_types = Mina_wire_types.Mina_base.Stack_frame.Digest

module Make_sig (A : Wire_types.Types.S) = struct
  module type S = Stack_frame_digest_intf with type Stable.V1.t = A.V1.t
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

  let gen = Field.Constant.gen

  let to_input (type p)
      ({ caller; caller_caller; calls } :
        ( Token_id.t
        , ( p
          , Zkapp_command.Digest.Account_update.t
          , Zkapp_command.Digest.Forest.t )
          Zkapp_command.Call_forest.t )
        frame ) =
    List.reduce_exn ~f:Random_oracle.Input.Chunked.append
      [ Token_id.to_input caller
      ; Token_id.to_input caller_caller
      ; Random_oracle.Input.Chunked.field
          (Zkapp_command.Call_forest.hash calls :> Field.Constant.t)
      ]

  let create frame =
    Random_oracle.hash ~init:Hash_prefix_states.account_update_stack_frame
      (Random_oracle.pack_input (to_input frame))

  module Checked = struct
    include Field

    let to_input (type zkapp_command)
        ~(hash_zkapp_command :
           zkapp_command -> Zkapp_command.Digest.Forest.Checked.t )
        ({ caller; caller_caller; calls } : _ frame) =
      List.reduce_exn ~f:Random_oracle.Input.Chunked.append
        [ Token_id.Checked.to_input caller
        ; Token_id.Checked.to_input caller_caller
        ; Random_oracle.Input.Chunked.field (hash_zkapp_command calls :> Field.t)
        ]

    let create ~hash_zkapp_command frame =
      Random_oracle.Checked.hash
        ~init:Hash_prefix_states.account_update_stack_frame
        (Random_oracle.Checked.pack_input (to_input ~hash_zkapp_command frame))
  end

  let typ = Field.typ
end

module Digest = Wire_types.Make (Make_sig) (Make_str)

module Checked = struct
  type nonrec 'zkapp_command t = (Token_id.Checked.t, 'zkapp_command) t

  let if_ f b ~then_ ~else_ : _ t =
    { caller = Token_id.Checked.if_ b ~then_:then_.caller ~else_:else_.caller
    ; caller_caller =
        Token_id.Checked.if_ b ~then_:then_.caller_caller
          ~else_:else_.caller_caller
    ; calls = f b ~then_:then_.calls ~else_:else_.calls
    }
end
