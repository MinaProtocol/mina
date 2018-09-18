open Coda_base
open Blockchain_snark

module Update : sig
  type t = New_chain of Blockchain.t
end

val accumulate :
     init:Blockchain.t
  -> parent_log:Logger.t
  -> prover:Prover.t
  -> updates:Update.t Linear_pipe.Reader.t
  -> strongest_chain:Blockchain.t Linear_pipe.Writer.t
  -> unit
