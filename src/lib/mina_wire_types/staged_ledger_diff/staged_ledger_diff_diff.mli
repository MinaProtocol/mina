open Utils

module Types : sig
  module type S = sig
    module At_most_two : sig
      module V1 : sig
        type 'a t = Zero | One of 'a option | Two of ('a * 'a option) option
      end
    end

    module Pre_diff_two : sig
      module V2 : sig
        type ('a, 'b) t =
          { completed_works : 'a list
          ; commands : 'b list
          ; coinbase : Mina_base_coinbase_fee_transfer.V1.t At_most_two.V1.t
          ; internal_command_statuses : Mina_base_transaction_status.V2.t list
          }
      end
    end

    module Pre_diff_with_at_most_two_coinbase : sig
      module V2 : sig
        type t =
          ( Transaction_snark_work.V2.t
          , Mina_base_user_command.V2.t Mina_base_with_status.V2.t )
          Pre_diff_two.V2.t
      end
    end

    module At_most_one : sig
      module V1 : sig
        type 'a t = Zero | One of 'a option
      end
    end

    module Pre_diff_one : sig
      module V2 : sig
        type ('a, 'b) t =
          { completed_works : 'a list
          ; commands : 'b list
          ; coinbase : Mina_base_coinbase_fee_transfer.V1.t At_most_one.V1.t
          ; internal_command_statuses : Mina_base_transaction_status.V2.t list
          }
      end
    end

    module Pre_diff_with_at_most_one_coinbase : sig
      module V2 : sig
        type t =
          ( Transaction_snark_work.V2.t
          , Mina_base_user_command.V2.t Mina_base_with_status.V2.t )
          Pre_diff_one.V2.t
      end
    end

    module Diff : sig
      module V2 : sig
        type t =
          Pre_diff_with_at_most_two_coinbase.V2.t
          * Pre_diff_with_at_most_one_coinbase.V2.t option
      end
    end

    module V2 : sig
      type t = { diff : Diff.V2.t }
    end
  end
end

module type Concrete = sig
  module Ft : sig
    module Stable : sig
      module V1 : sig
        type t = Mina_base_coinbase_fee_transfer.V1.t
      end
    end
  end

  module At_most_two : sig
    module V1 : sig
      type 'a t = Zero | One of 'a option | Two of ('a * 'a option) option
    end
  end

  module Pre_diff_two : sig
    module V2 : sig
      type ('a, 'b) t =
        { completed_works : 'a list
        ; commands : 'b list
        ; coinbase : Mina_base_coinbase_fee_transfer.V1.t At_most_two.V1.t
        ; internal_command_statuses : Mina_base_transaction_status.V2.t list
        }
    end
  end

  module Pre_diff_with_at_most_two_coinbase : sig
    module V2 : sig
      type t =
        ( Transaction_snark_work.V2.t
        , Mina_base_user_command.V2.t Mina_base_with_status.V2.t )
        Pre_diff_two.V2.t
    end
  end

  module At_most_one : sig
    module V1 : sig
      type 'a t = Zero | One of 'a option
    end
  end

  module Pre_diff_one : sig
    module V2 : sig
      type ('a, 'b) t =
        { completed_works : 'a list
        ; commands : 'b list
        ; coinbase : Mina_base_coinbase_fee_transfer.V1.t At_most_one.V1.t
        ; internal_command_statuses : Mina_base_transaction_status.V2.t list
        }
    end
  end

  module Pre_diff_with_at_most_one_coinbase : sig
    module V2 : sig
      type t =
        ( Transaction_snark_work.V2.t
        , Mina_base_user_command.V2.t Mina_base_with_status.V2.t )
        Pre_diff_one.V2.t
    end
  end

  module Diff : sig
    module V2 : sig
      type t =
        Pre_diff_with_at_most_two_coinbase.V2.t
        * Pre_diff_with_at_most_one_coinbase.V2.t option
    end
  end

  module V2 : sig
    type t = { diff : Diff.V2.t }
  end
end

module M : Types.S

module type Local_sig = Signature(Types).S

module Make
    (Signature : Local_sig) (_ : functor (A : Concrete) -> Signature(A).S) :
  Signature(M).S

include
  Types.S
    with module At_most_two = M.At_most_two
     and module Pre_diff_two = M.Pre_diff_two
     and module Pre_diff_with_at_most_two_coinbase = M
                                                     .Pre_diff_with_at_most_two_coinbase
     and module At_most_one = M.At_most_one
     and module Pre_diff_one = M.Pre_diff_one
     and module V2 = M.V2
