module Container_images = struct
  type t = {coda: string; user_agent: string; bots: string; points: string}
end

module Block_producer = struct
  type t = {balance: string; timing: Mina_base.Account_timing.t}
end

type constants =
  { constraints: Genesis_constants.Constraint_constants.t
  ; genesis: Genesis_constants.t }

type t =
  { k: int
  ; delta: int
  ; slots_per_epoch: int
  ; slots_per_sub_window: int
  ; proof_level: Runtime_config.Proof_keys.Level.t
  ; txpool_max_size: int
  ; block_producers: Block_producer.t list
  ; num_snark_workers: int
  ; snark_worker_fee: string
  ; snark_worker_public_key: string }

let default =
  { k= 20
  ; slots_per_epoch= 3 * 8 * 20
  ; slots_per_sub_window= 2
  ; delta= 0
  ; proof_level= Full
  ; txpool_max_size= 3000
  ; num_snark_workers= 2
  ; block_producers= []
  ; snark_worker_fee= "0.025"
  ; snark_worker_public_key=
      (let pk, _ = (Lazy.force Mina_base.Sample_keypairs.keypairs).(0) in
       Signature_lib.Public_key.Compressed.to_string pk) }
