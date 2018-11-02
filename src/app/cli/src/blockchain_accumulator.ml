open Core
open Async
open Coda_base
open Blockchain_snark
module Digest = Snark_params.Tick.Pedersen.Digest

module Update = struct
  type t = New_chain of Blockchain.t
end

let accumulate ~init ~parent_log ~prover ~updates ~strongest_chain =
  let log = Logger.child parent_log "blockchain_accumulator" in
  don't_wait_for
    (let%map _last_block =
       Linear_pipe.fold updates ~init
         ~f:(fun (chain : Blockchain.t) (Update.New_chain new_chain) ->
           match%bind Prover.verify_blockchain prover new_chain with
           | Error e ->
               Logger.error log "%s"
                 (Error.to_string_hum (Error.tag e ~tag:"prover verify failed")) ;
               return chain
           | Ok false -> return chain
           | Ok true ->
               if
                 let open Strength in
                 new_chain.state.strength > chain.Blockchain.state.strength
               then
                 let%map () = Pipe.write strongest_chain new_chain in
                 new_chain
               else return chain )
     in
     ())
