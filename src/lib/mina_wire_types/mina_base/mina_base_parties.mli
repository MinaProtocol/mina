open Utils

module Valid : sig
  module Verification_key_hash : sig
    module V1 : sig
      type t = Mina_base_zkapp_basic.F.V1.t
    end
  end
end

module Digest_types : sig
  module type S = sig
    module Party : sig
      module V1 : sig
        type t = private Pasta_bindings.Fp.t
      end
    end

    module Forest : sig
      module V1 : sig
        type t = private Pasta_bindings.Fp.t
      end
    end
  end
end

module Digest_M : sig
  module Party : sig
    module V1 : sig
      type t = private Pasta_bindings.Fp.t
    end
  end

  module Forest : sig
    module V1 : sig
      type t = private Pasta_bindings.Fp.t
    end
  end
end

module type Digest_concrete = sig
  module Party : sig
    module V1 : sig
      type t = Pasta_bindings.Fp.t
    end
  end

  module Forest : sig
    module V1 : sig
      type t = Pasta_bindings.Fp.t
    end
  end
end

module type Digest_local_sig = Signature(Digest_types).S

module Digest_make
    (Signature : Digest_local_sig) (F : functor (A : Digest_concrete) ->
      Signature(A).S) : Signature(Digest_M).S

module Call_forest : sig
  module Digest :
    Digest_types.S
      with module Party = Digest_M.Party
       and module Forest = Digest_M.Forest

  module Tree : sig
    module V1 : sig
      type ('party, 'party_digest, 'digest) t =
        { party : 'party
        ; party_digest : 'party_digest
        ; calls :
            ( ('party, 'party_digest, 'digest) t
            , 'digest )
            Mina_base_with_stack_hash.V1.t
            list
        }
    end
  end

  module V1 : sig
    type ('party, 'party_digest, 'digest) t =
      ( ('party, 'party_digest, 'digest) Tree.V1.t
      , 'digest )
      Mina_base_with_stack_hash.V1.t
      list
  end
end

module V1 : sig
  type t =
    { fee_payer : Mina_base_party.Fee_payer.V1.t
    ; other_parties :
        ( Mina_base_party.V1.t
        , Call_forest.Digest.Party.V1.t
        , Call_forest.Digest.Forest.V1.t )
        Call_forest.V1.t
    ; memo : Mina_base_signed_command_memo.V1.t
    }
end
