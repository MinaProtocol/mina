(** The query of [Send_archive_diff] (see {!Rpc.t}): what a daemon tells the
    archive as its transition frontier changes.

    These types are {b not versioned}: they derive bin_prot directly, so their
    encoding is whatever the current sources say. A daemon and an archive that
    exchange them must be built from the same protocol version. *)

open Mina_base
module Breadcrumb = Transition_frontier.Breadcrumb

module Transition_frontier : sig
  type t =
    | Breadcrumb_added of
        { block :
            Mina_block.Stable.Latest.t
            State_hash.With_state_hashes.Stable.Latest.t
              (** The block with its state hashes, proofs read in from disk. *)
        ; accounts_accessed : (int * Account.Stable.Latest.t) list
              (** Every account the block's commands read or wrote, with its
                  ledger index, as it stands after the block. *)
        ; accounts_created :
            (Account_id.Stable.Latest.t * Currency.Fee.Stable.Latest.t) list
              (** Accounts the block created, with the creation fee paid. *)
        ; tokens_used :
            (Token_id.Stable.Latest.t * Account_id.Stable.Latest.t option) list
              (** Every token the block touched, with its owner when it has
                  one. *)
        ; sender_receipt_chains_from_parent_ledger :
            (Account_id.Stable.Latest.t * Receipt.Chain_hash.Stable.Latest.t)
            list
              (** The receipt chain hash of every fee payer, from the parent
                  ledger. *)
        }
        (** A block was added to the frontier. The only diff the daemon
            sends. *)
    | Root_transitioned of
        Transition_frontier.Diff.Root_transition.Lite.Stable.Latest.t
        (** The frontier root moved. Not sent today; the archive ignores it. *)
    | Bootstrap of { lost_blocks : State_hash.Stable.Latest.t list }
        (** The daemon bootstrapped and dropped these blocks. Not sent today;
            the archive ignores it. *)

  include Bin_prot.Binable.S with type t := t
end

module Transaction_pool : sig
  (** A change in the daemon's transaction pool. Not part of {!t} and not sent
      to the archive. *)
  type t =
    { added : User_command.Stable.Latest.t list
    ; removed : User_command.Stable.Latest.t list
    }

  include Bin_prot.Binable.S with type t := t
end

type t = Transition_frontier of Transition_frontier.t

include Bin_prot.Binable.S with type t := t

module Builder : sig
  (** The [Breadcrumb_added] diff for a breadcrumb of the daemon's frontier.
      Reads the accounts the block touched from the breadcrumb's staged
      ledger, so it must run while that ledger is still the block's.

      @raise if a fee payer of the block is missing from the ledger. *)
  val breadcrumb_added :
       precomputed_values:Precomputed_values.t
    -> logger:Logger.t
    -> Breadcrumb.t
    -> Transition_frontier.t
end
