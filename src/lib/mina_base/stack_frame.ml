open Core_kernel

[%%versioned
module Stable = struct
  module V1 = struct
    type ('caller, 'parties) t =
      { caller : 'caller; caller_caller : 'caller; calls : 'parties }
    [@@deriving make, fields, sexp, yojson]
  end
end]

type value =
  ( Token_id.t
  , ( Party.t
    , Parties.Digest.Party.t
    , Parties.Digest.Forest.t )
    Parties.Call_forest.t )
  t

type ('caller, 'parties) frame = ('caller, 'parties) t

let empty : value =
  { caller = Token_id.default; caller_caller = Token_id.default; calls = [] }

module Digest : sig
  include Digest_intf.S

  val create :
       ( Token_id.t
       , ( 'p
         , Parties.Digest.Party.t
         , Parties.Digest.Forest.t )
         Parties.Call_forest.t )
       frame
    -> t

  val gen : t Quickcheck.Generator.t

  open Pickles.Impls.Step

  module Checked : sig
    include Digest_intf.S_checked

    val create :
         hash_parties:('parties -> Parties.Digest.Forest.Checked.t)
      -> (Token_id.Checked.t, 'parties) frame
      -> t
  end

  val typ : (Checked.t, t) Typ.t
end = struct
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
          , Parties.Digest.Party.t
          , Parties.Digest.Forest.t )
          Parties.Call_forest.t )
        frame ) =
    List.reduce_exn ~f:Random_oracle.Input.Chunked.append
      [ Token_id.to_input caller
      ; Token_id.to_input caller_caller
      ; Random_oracle.Input.Chunked.field
          (Parties.Call_forest.hash calls :> Field.Constant.t)
      ]

  let create frame =
    Random_oracle.hash ~init:Hash_prefix_states.party_stack_frame
      (Random_oracle.pack_input (to_input frame))

  module Checked = struct
    include Field

    let to_input (type parties)
        ~(hash_parties : parties -> Parties.Digest.Forest.Checked.t)
        ({ caller; caller_caller; calls } : _ frame) =
      List.reduce_exn ~f:Random_oracle.Input.Chunked.append
        [ Token_id.Checked.to_input caller
        ; Token_id.Checked.to_input caller_caller
        ; Random_oracle.Input.Chunked.field (hash_parties calls :> Field.t)
        ]

    let create ~hash_parties frame =
      Random_oracle.Checked.hash ~init:Hash_prefix_states.party_stack_frame
        (Random_oracle.Checked.pack_input (to_input ~hash_parties frame))
  end

  let typ = Field.typ
end

module Checked = struct
  type nonrec 'parties t = (Token_id.Checked.t, 'parties) t

  let if_ f b ~then_ ~else_ : _ t =
    { caller = Token_id.Checked.if_ b ~then_:then_.caller ~else_:else_.caller
    ; caller_caller =
        Token_id.Checked.if_ b ~then_:then_.caller_caller
          ~else_:else_.caller_caller
    ; calls = f b ~then_:then_.calls ~else_:else_.calls
    }
end
