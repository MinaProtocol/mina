open Mina_wire_types

type t =
  Transaction_snark_work.Statement.V2.t
  * Ledger_proof.V2.t One_or_two.V1.t Network_pool_priced_proof.V1.t
