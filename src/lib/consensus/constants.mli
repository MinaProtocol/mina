[%%import "../../config.mlh"]

(** The timestamp for the genesis block *)
val genesis_state_timestamp : Coda_base.Block_time.t

(** [k] is the number of blocks required to reach finality *)
val k : int

(** The amount of money minted and given to the proposer whenever a block
 * is created *)
val coinbase : Currency.Amount.t

val block_window_duration_ms : int

(** The window duration in which blocks are created *)
val block_window_duration : Coda_base.Block_time.Span.t

(** [delta] is the number of slots in the valid window for receiving blocks over the network *)
val delta : int

(** [c] is the number of slots in which we can probalistically expect at least 1
 * block. In sig, it's exactly 1 as blocks should be produced every slot. *)
val c : int
