open Core_kernel
open Coda_base

(** Receipt_chain_database is a data structure that stores a client's
    user commands and their corresponding receipt_chain_hash. A client
    uses this database to prove that they sent a payment by showing
    a verifier a Merkle list of their payment from their latest
    payment to the payment that they are trying to prove.

    Each account has a receipt_chain_hash field, which is a certificate
    of all the user commands that an account has send. If an account has
    sent user commands u_n ... u_1 and h_n ... h_1 is the hash of the
    payload of these user commands, then the receipt_chain_hash, $r_n$,
    is equal to the following:

    $$ r_n = H(h_n, H(h_{n - 1}, ...)) $$

    where H is the hash function that determines the receipt_chain_hash
    that takes as input the hash of a payment payload and it's
    preceding receipt_chain_hash.

    *)
module type S = sig
  type t

  type config

  module M : Key_value_database.Monad.S

  val create : config -> t

  (** [prove t ~proving_receipt ~resulting_receipt] will provide a proof of a
      `proving_receipt` hash up to an underlying `resulting_receipt` hash. The
      proof will consist of an initial proving_receipt and a list of user
      commands leading to resulting_receipt. Note the user_command of
      `proving_receipt` is omitted from the proof *)
  val prove :
       t
    -> proving_receipt:Receipt.Chain_hash.t
    -> resulting_receipt:Receipt.Chain_hash.t
    -> (Receipt.Chain_hash.t * User_command.t list) Or_error.t M.t

  (** [verify t ~init merkle_list receipt_chain] will verify the proof produced
      by `prove`. Namely, it will verify that a user has sent a series of user
      commands from a `resulting_receipt` to a `proving_receipt`. *)
  val verify :
       init:Receipt.Chain_hash.t
    -> User_command.t sexp_list
    -> Receipt.Chain_hash.t
    -> Receipt.Chain_hash.t Non_empty_list.t option

  val get_payment :
    t -> receipt:Receipt.Chain_hash.t -> User_command.t option M.t

  (** Add stores a payment into a client's database as a value.
      The key is computed by using the payment payload and the previous receipt_chain_hash.
      This receipt_chain_hash is computed within the `add` function. As a result,
      the computed receipt_chain_hash is returned *)
  val add :
       t
    -> previous:Receipt.Chain_hash.t
    -> User_command.t
    -> [ `Ok of Receipt.Chain_hash.t
       | `Duplicate of Receipt.Chain_hash.t
       | `Error_multiple_previous_receipts of Receipt.Chain_hash.t ]
       M.t
end

module type Tree_node = sig
  module Stable : sig
    module V1 : sig
      type t =
        { key: Receipt.Chain_hash.Stable.V1.t
        ; value: User_command.Stable.V1.t
        ; parent: Receipt.Chain_hash.Stable.V1.t }
      [@@deriving bin_io, sexp, version]
    end

    module Latest = V1
  end

  type t = Stable.Latest.t =
    { key: Receipt.Chain_hash.t
    ; value: User_command.t
    ; parent: Receipt.Chain_hash.t }
  [@@deriving sexp]
end
