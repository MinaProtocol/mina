open Core
open Fold_lib
open Tuple_lib
open Snark_params.Tick
open Coda_digestif
open Module_version

module Aux_hash = struct
  let length_in_bits = 256

  let length_in_bytes = length_in_bits / 8

  module Stable = struct
    module V1 = struct
      module T = struct
        let version = 1

        type t = string [@@deriving bin_io, sexp, eq, compare, hash]
      end

      include T
      include Registration.Make_latest_version (T)
    end

    module Latest = V1

    module Module_decl = struct
      let name = "staged_ledger_hash_aux_hash"

      type latest = Latest.t
    end

    module Registrar = Registration.Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)
  end

  include Stable.Latest

  let of_bytes = Fn.id

  let to_bytes = Fn.id

  let dummy : t = String.init length_in_bytes ~f:(fun _ -> '\000')
end

module Pending_coinbase_extra = struct
  let length_in_bits = 256

  let length_in_bytes = length_in_bits / 8

  module Stable = struct
    module V1 = struct
      module T = struct
        let version = 1

        type t = string [@@deriving bin_io, sexp, eq, compare, hash]
      end

      include T
      include Registration.Make_latest_version (T)
    end

    module Latest = V1

    module Module_decl = struct
      let name = "staged_ledger_hash_pending_coinbase_state_hash"

      type latest = Latest.t
    end

    module Registrar = Registration.Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)
  end

  include Stable.Latest

  let of_bytes = Fn.id

  let to_bytes = Fn.id

  let dummy : t = String.init length_in_bytes ~f:(fun _ -> '\000')
end

module Non_snark = struct
  module Stable = struct
    module V1 = struct
      module T = struct
        let version = 1

        type t =
          { ledger_hash: Ledger_hash.Stable.V1.t
          ; aux_hash: Aux_hash.t
          ; pending_coinbase_extra: Pending_coinbase_extra.t }
        [@@deriving bin_io, sexp, eq, compare, hash]
      end

      include T
      include Registration.Make_latest_version (T)
    end

    module Latest = V1

    module Module_decl = struct
      let name = "staged_ledger_hash_pending_coinbase_state_hash"

      type latest = Latest.t
    end

    module Registrar = Registration.Make (Module_decl)
    module Registered_V1 = Registrar.Register (V1)
  end

  include Stable.Latest

  type value = t [@@deriving bin_io, sexp, compare, hash]

  let dummy =
    { ledger_hash= Ledger_hash.of_hash Field.zero
    ; aux_hash= Aux_hash.dummy
    ; pending_coinbase_extra= Pending_coinbase_extra.dummy }

  type var = Boolean.var Triple.t list

  let length_in_bits = 256

  let length_in_triples = (length_in_bits + 2) / 3

  let digest {ledger_hash; aux_hash; pending_coinbase_extra} =
    let h = Digestif.SHA256.init () in
    let h = Digestif.SHA256.feed_string h (Ledger_hash.to_bytes ledger_hash) in
    let h = Digestif.SHA256.feed_string h aux_hash in
    let h = Digestif.SHA256.feed_string h pending_coinbase_extra in
    (Digestif.SHA256.get h :> string)

  let fold t = Fold.string_triples (digest t)

  let ledger_hash {ledger_hash; _} = ledger_hash

  let aux_hash {aux_hash; _} = aux_hash

  let of_ledger_aux_coinbase_hash aux_hash ledger_hash pending_coinbase_extra =
    {aux_hash; ledger_hash; pending_coinbase_extra}

  let var_to_triples = Checked.return

  let var_of_t t : var =
    List.map
      (Fold.to_list @@ fold t)
      ~f:(fun (x, y, z) ->
        let g = Boolean.var_of_value in
        (g x, g y, g z) )

  let typ : (var, value) Typ.t =
    let triple t = Typ.tuple3 t t t in
    Typ.transport
      (Typ.list ~length:length_in_triples (triple Boolean.typ))
      ~there:(Fn.compose Fold.to_list fold)
      ~back:(fun _ ->
        (* If we put a failwith here, we lose the ability to printf-inspect
        * anything that uses staged-ledger-hashes from within Checked
        * computations. It's useful when debugging to dump the protocol state
        * and so we can just lie here instead. *)
        printf "WARNING: improperly transporting staged-ledger-hash\n" ;
        dummy )
end

module Stable = struct
  module V1 = struct
    module T = struct
      let version = 1

      type ('non_snark, 'pending_coinbase_hash) t_ =
        {non_snark: 'non_snark; pending_coinbase_hash: 'pending_coinbase_hash}
      [@@deriving bin_io, sexp, eq, compare, hash]

      (** Staged ledger hash has two parts
      1) merkle root of the pending coinbases
      2) ledger hash, aux hash, and the FIFO order of the coinbase stacks(Non snark). 
      Only part 1 is required for blockchain snark computation and therefore the remaining fields of the staged ledger are grouped together as "Non_snark" 
      *)
      type t = (Non_snark.Stable.V1.t, Pending_coinbase.Hash.t) t_
      [@@deriving bin_io, sexp, eq, compare, hash]
    end

    include T
    include Registration.Make_latest_version (T)
    include Hashable.Make_binable (T)
  end

  module Latest = V1

  module Module_decl = struct
    let name = "staged_ledger_hash"

    type latest = Latest.t
  end

  module Registrar = Registration.Make (Module_decl)
  module Registered_V1 = Registrar.Register (V1)
end

include Stable.Latest

let ledger_hash {non_snark; _} = Non_snark.ledger_hash non_snark

let aux_hash {non_snark; _} = Non_snark.aux_hash non_snark

let pending_coinbase_hash {pending_coinbase_hash; _} = pending_coinbase_hash

let pending_coinbase_hash_var {pending_coinbase_hash; _} =
  pending_coinbase_hash

let of_aux_ledger_and_coinbase_hash aux_hash ledger_hash pending_coinbase =
  { non_snark=
      Non_snark.of_ledger_aux_coinbase_hash aux_hash ledger_hash
        (Pending_coinbase.hash_extra pending_coinbase)
  ; pending_coinbase_hash= Pending_coinbase.merkle_root pending_coinbase }

type value = (Non_snark.t, Pending_coinbase.Hash.t) t_
[@@deriving bin_io, sexp, eq, compare, hash]

type var = (Non_snark.var, Pending_coinbase.Hash.var) t_

let genesis =
  let pending_coinbase = Pending_coinbase.create () |> Or_error.ok_exn in
  { non_snark= Non_snark.dummy
  ; pending_coinbase_hash= Pending_coinbase.merkle_root pending_coinbase }

let var_of_t ({pending_coinbase_hash; non_snark} : t) =
  let non_snark = Non_snark.var_of_t non_snark in
  let pending_coinbase_hash =
    Pending_coinbase.Hash.var_of_t pending_coinbase_hash
  in
  {non_snark; pending_coinbase_hash}

let fold (t : t) =
  Fold.(
    Non_snark.fold t.non_snark
    +> Pending_coinbase.Hash.fold t.pending_coinbase_hash)

let length_in_triples =
  Non_snark.length_in_triples + Pending_coinbase.Hash.length_in_triples

let var_to_triples (t : var) =
  let%map non_snark_triples = Non_snark.var_to_triples t.non_snark
  and pending_coinbase_hash_triples =
    Pending_coinbase.Hash.var_to_triples t.pending_coinbase_hash
  in
  non_snark_triples @ pending_coinbase_hash_triples

let to_hlist {non_snark; pending_coinbase_hash} =
  H_list.[non_snark; pending_coinbase_hash]

let of_hlist : (unit, 'lx -> 'ph -> unit) H_list.t -> ('lx, 'ph) t_ =
  H_list.(
    fun [non_snark; pending_coinbase_hash] -> {non_snark; pending_coinbase_hash})

let data_spec =
  let open Data_spec in
  [Non_snark.typ; Pending_coinbase.Hash.typ]

let typ : (var, t) Typ.t =
  Typ.of_hlistable data_spec ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist
