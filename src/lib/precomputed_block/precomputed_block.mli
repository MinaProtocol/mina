(* precomputed_block.mli *)

open Async
open Core


module Id : sig
  
  type t = Mina_numbers.Length.t * Mina_base.State_hash.t
    [@@deriving compare, sexp]

  include Comparable.S with type t := t

  val filename : network:String.t -> (Mina_numbers.Length.t * Mina_base.State_hash.t) -> String.t

end

type blockchain_state = { snarked_ledger_hash : Mina_base.Ledger_hash.t }

type consensus_state =
  { blockchain_length : Mina_numbers.Length.t
  ; block_creator : Signature_lib.Public_key.Compressed.t
  ; block_stake_winner : Signature_lib.Public_key.Compressed.t
  ; last_vrf_output : string
  ; staking_epoch_data : Mina_base.Epoch_data.t
  ; next_epoch_data : Mina_base.Epoch_data.t
  ; min_window_density : Mina_numbers.Length.t
  ; sub_window_densities : Mina_numbers.Length.t list
  ; total_currency : Currency.Amount.t
  }

type protocol_state_body =
  { blockchain_state : blockchain_state; consensus_state : consensus_state }

type protocol_state = { body : protocol_state_body }

type t = { protocol_state : protocol_state }

val of_block_header : Mina_block.Header.t -> t

val of_yojson : Yojson.Safe.t -> t

val block_filename_regexp: network:String.t -> Str.regexp

val parse_filename : String.t -> (String.t * Mina_numbers.Length.t * Mina_base.State_hash.t) option

val list_directory : network:String.t -> path:String.t -> Id.Set.t Deferred.t 

val concrete_fetch_batch : logger:Logger.t -> bucket:String.t -> network:String.t ->  Id.t list -> local_path:String.t -> t Mina_base.State_hash.Map.t Deferred.t 

val delete_fetched_concrete : local_path:String.t -> network: String.t -> (Unsigned.UInt32.t * Pasta_bindings.Fp.t) list -> unit Deferred.t

val delete_fetched : network: String.t  -> path:String.t -> unit Deferred.t
