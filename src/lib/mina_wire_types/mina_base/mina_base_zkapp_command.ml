open Utils

module Digest_types = struct
  module type S = sig
    module Account_update : sig
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

module Digest_M = struct
  module Account_update = struct
    module V1 = struct
      type t = Pasta_bindings.Fp.t
    end
  end

  module Forest = struct
    module V1 = struct
      type t = Pasta_bindings.Fp.t
    end
  end
end

module type Digest_concrete = sig
  module Account_update : sig
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
      Signature(A).S) =
  F (Digest_M)

module Call_forest = struct
  module Digest = Digest_M

  module Tree = struct
    module V1 = struct
      type ('account_update, 'account_update_digest, 'digest) t =
        { account_update : 'account_update
        ; account_update_digest : 'account_update_digest
        ; calls :
            ( ('account_update, 'account_update_digest, 'digest) t
            , 'digest )
            Mina_base_with_stack_hash.V1.t
            list
        }
    end
  end

  module V1 = struct
    type ('account_update, 'account_update_digest, 'digest) t =
      ( ('account_update, 'account_update_digest, 'digest) Tree.V1.t
      , 'digest )
      Mina_base_with_stack_hash.V1.t
      list
  end
end

module V1 = struct
  type t =
    { fee_payer : Mina_base_account_update.Fee_payer.V1.t
    ; account_updates :
        ( Mina_base_account_update.V1.t
        , Call_forest.Digest.Account_update.V1.t
        , Call_forest.Digest.Forest.V1.t )
        Call_forest.V1.t
    ; memo : Mina_base_signed_command_memo.V1.t
    }
end

module Valid = struct
  module Verification_key_hash = struct
    module V1 = struct
      type t = Mina_base_zkapp_basic.F.V1.t
    end
  end

  module V1 = struct
    type t =
      { zkapp_command : V1.t
      ; verification_keys :
          (Mina_base_account_id.V2.t * Verification_key_hash.V1.t) list
      }
  end
end
