open Core_kernel
open Universe.Crypto

let attribute_count = 10

let int_to_bits len c =
  List.init len ~f:(fun i -> Int.((c lsl i) land 1 = 1))

let string_to_bits s =
  let char_to_bits c = int_to_bits 8 (Char.to_int c) in
  List.concat_map (String.to_list s) ~f:char_to_bits

open Impl

module Field = struct
  include Impl.Field

  let to_yojson x = `String (to_string x)

  let of_yojson = function
    | `String x -> Ok (of_string x)
    | _ -> Error "Hash of json failure"
end

module Proof = Impl.Proof

module Mask : sig
  type t
end = struct
  type t = bool array
end

module Masked_set : sig
  type 'a t = 'a option array [@@deriving bin_io]

  val typ : ('a, 'b) Typ.t -> null:'b -> ('a array, 'b t) Typ.t
end = struct
  type 'a t = 'a option array [@@deriving bin_io]

  let typ elt ~null =
    let elt_opt = 
      Typ.transport elt
        ~back:Option.return
        ~there:(function
            | None -> null
            | Some x -> x)
    in
    Typ.array ~length:attribute_count elt_opt
end

module Hash : sig
  type t = Universe.Hash.Digest.t [@@deriving bin_io, eq, compare, sexp, yojson]

  val hash : t -> t

  module Checked : sig
    type t = Universe.Hash.Checked.t

    val null : t

    val hash : t -> t

    val equal : t -> t -> Boolean.var
  end

  val typ : (Checked.t, t) Typ.t

  val null : t
end = struct
  type t = Field.t [@@deriving bin_io, eq, sexp, compare, yojson]

  let null = Field.zero

  let hash = Fn.id

  module Checked = struct
    open Run
    type t = Field.t

    let hash = Fn.id

    let null = Field.constant null

    let equal = Field.equal
  end

  let typ = Field.typ
end

module Election_description = struct
  module T = struct
    type t =
      { description : string
      ; timestamp : Time.t sexp_opaque
      }
    [@@deriving bin_io, compare, sexp]
  end
  include T
  include Comparable.Make(T)

  module Commitment = Hash

  open Universe

  let commit ({description; timestamp} : t) : Commitment.t =
    let time = 
      Time.Span.to_sec (Time.to_span_since_epoch timestamp)
      |> Float.to_int
      |> int_to_bits 32
    in
    let desc = string_to_bits description in
    Hash.(
      hash
        (pack_input
          (Input.bitstrings [| time; desc |])))
end

module Private_key : sig
  type t = private Field.t [@@deriving bin_io, yojson]

  val create : unit -> t

  module Checked : sig
    type t = private Field.Var.t
  end

  val typ : (Checked.t, t) Typ.t

end = struct
  type t = Field.t[@@deriving bin_io, yojson]

  let create = Field.random

  module Checked = Field.Var

  let typ = Field.typ
end

module Nullifier : sig
  type t [@@deriving bin_io]

  val create
    : Private_key.t
    -> Election_description.Commitment.t
    -> t

  module Checked : sig
    type t

    val assert_equal : t -> t -> unit

    val create
      : Private_key.Checked.t
      -> Election_description.Commitment.Checked.t
      -> t
  end

  val typ : (Checked.t, t) Typ.t

  include Comparable.S_binable with type t := t
end = struct
  type t = Field.t [@@deriving bin_io]

  open Universe

  (* TODO: Domain separation *)
  let create (private_key : Private_key.t) (c : Election_description.Commitment.t) : t =
    Hash.hash
      [| (private_key :> Field.t); c |]

  module Checked = struct
    open Run
    type t = Field.t
    let assert_equal = Field.Assert.equal

  let create (private_key : Private_key.Checked.t) (c : Election_description.Commitment.Checked.t) : t =
    Hash.Checked.hash
      [| (private_key :> Field.t); c |]

  end

  let typ = Field.typ
  include Comparable.Make_binable(Field)
end

module Voter = struct
  module Attribute : sig
    type t = { key: string;  value : string } [@@deriving bin_io, yojson]

    module Commitment : sig
      type t = private Field.t


      val hash : t -> Hash.t

      module Checked : sig
        type t = Run.Field.t

        val null : t

        val equal : t -> t -> Boolean.var

        val hash : t -> Hash.Checked.t
      end

      val typ : (Checked.t, t) Typ.t

      val null : t
    end

    val commit : t -> Commitment.t
  end = struct
    type t = { key: string;  value : string } [@@deriving bin_io, yojson]

    module Commitment = Hash

    open Universe

    (* TODO: Proper separation of key and value... *)
    let commit { key; value } =
      Hash.(hash
             (pack_input (Input.bitstring (string_to_bits (key ^":"^ value)))))
  end

  type ('priv_key, 'attrs) t_ =
    { private_key : 'priv_key
    ; attributes : 'attrs
    }[@@deriving bin_io, yojson]

  type t = (Private_key.t, Attribute.t array) t_ [@@deriving bin_io, yojson]

    let commit ({ private_key; attributes } : t) =
      let open Universe.Hash in
      let input =
        Input.(
          append 
            (field_elements 
               (Array.map attributes ~f:(fun x -> (Attribute.commit x :> Field.t) )) )
            (field
               (private_key :> Field.t)) )
      in
      (hash (pack_input input))

  module Checked = struct
    type t =
      ( Private_key.Checked.t
      , Attribute.Commitment.Checked.t array) t_

    let commit ({ private_key; attributes } : t) =
      let open Run in
      let open Universe.Hash in
      let input =
        Input.(
          append 
            (field_elements attributes)
            (field 
               (private_key :> Field.t)) )
      in
      Checked.(hash (pack_input input))
  end

  let typ : (Checked.t, t) Typ.t =
    let open Snarky in
    let to_hlist { private_key; attributes } =
      H_list.[ private_key; attributes ]
    in
    let of_hlist ([ private_key; attributes ] : (unit, _) H_list.t)  =
      { private_key; attributes }
    in
    Typ.of_hlistable
      [ Private_key.typ
      ; Typ.array ~length:attribute_count
          (Typ.transport Attribute.Commitment.typ
             ~there:Attribute.commit
             ~back:(fun _ -> failwith "Cannot decommit")
          ) ]
      ~var_to_hlist:to_hlist
      ~var_of_hlist:of_hlist
      ~value_to_hlist:to_hlist
      ~value_of_hlist:of_hlist

  module Commitment = Hash
end

module Vote = struct
  type t = Yes | No [@@deriving bin_io]

  let typ =
    Typ.transport Boolean.typ
      ~there:(function Yes -> true | No -> false)
      ~back:(function true -> Yes | false -> No)
end

module Voter_tree = Universe.Merkle_tree(Voter.Commitment)

module Snark = struct
  let input () =
    Data_spec.[
      Hash.typ
      ; Nullifier.typ
      ; Vote.typ
      ; Masked_set.typ 
          Voter.Attribute.Commitment.typ 
          ~null:Voter.Attribute.Commitment.null
      ; Election_description.Commitment.typ
    ]

  open Universe

  (* There exists a commitment `c` in the set of commitments with root `voters_root`
     and a voter `v` such that 

     v = decommit(c)
     
     nullifier = hash(v.secret_key, "Nullifier", election)

     attributes =
        exists mask.
          Voter.Attribute_set.mask v.attributes mask
  *)

  let depth = 25

  open Run
  module Request = Snarky.Request

  type _ Request.t +=
    | Voter       : Voter.t Request.t
    | Voter_index : Voter_tree.Index.t Request.t
    | Voter_path  : Hash.Digest.t list Request.t

  let main voters_root nullifier _vote masked_attributes election = 
    let voter =
      let index =
        exists (Voter_tree.Index.typ ~depth)
          ~request:(fun () -> Voter_index)
      in
      let path =
        exists (Typ.list ~length:depth Hash.Digest.typ)
          ~request:(fun () -> Voter_path)
      in
      let voter =
        exists Voter.typ
          ~request:(fun () -> Voter)
      in
      let comm = Voter.Checked.commit voter in
      Voter_tree.Checked.check_membership
        ~root:voters_root
        comm
        index
        path;
      voter
    in
    for i = 0 to attribute_count - 1 do
      let claimed_attr = masked_attributes.(i) in
      let attr = voter.attributes.(i) in
      let open Voter.Attribute.Commitment.Checked in
      Boolean.Assert.any
        [ equal claimed_attr attr
        ; equal claimed_attr null
        ]
    done;
    Nullifier.Checked.assert_equal nullifier
      (Nullifier.Checked.create voter.private_key election)
end

module Statement = struct
  (* There exists a commitment `c` in the set of commitments with root `voters_root`
     and a voter `v` such that 

     v = decommit(c)
     
     nullifier = hash(v.secret_key, "Nullifier", election)

     attributes =
        exists mask.
          Voter.Attribute_set.mask v.attributes mask
  *)
  type t =
    { voters_root : Hash.t
    ; nullifier   : Nullifier.t
    ; vote        : Vote.t (* Should really be the message in the SoK... or else the SNARK should witness a signature with a privkey or something *)
    ; attributes  : Voter.Attribute.t Masked_set.t
    ; election    : Election_description.t
    }
  [@@deriving bin_io]

  let verify { voters_root; nullifier; vote; attributes; election } proof ~verification_key =
    let attribute_commitments = 
      Array.map attributes ~f:(Option.map ~f:Voter.Attribute.commit)
    in
    verify proof verification_key
      (Snark.input ())
      voters_root
      nullifier
      vote
      attribute_commitments
      (Election_description.commit election)
end

module Error = struct
  type t =
    | Duplicate_nullifier
    | Merkle_root_mismatch
    | Invalid_proof
  [@@deriving sexp]

  let to_error t =
    Error.of_string (Sexp.to_string_hum (sexp_of_t t))

  let to_or_error t = Error (to_error t)
end

module Config = struct
  type t =
    { voters_root : Hash.t
    ; verification_key: Verification_key.t
    }
end 

module Election_status = struct
  type t =
    { yes : int
    ; no : int
    }
end

module Elections_state : sig
  type t

  val create : Config.t -> t

  val add_vote : t -> Statement.t * Proof.t -> (t, Error.t) Result.t

  val elections : t -> Election_status.t Election_description.Map.t
end = struct
  type t =
    { nullifiers : Vote.t Nullifier.Map.t Election_description.Map.t
    ; config : Config.t
    }

  let create config =
    { config
    ; nullifiers = Election_description.Map.empty
    }

  let elections { nullifiers; _ } =
    Map.map nullifiers ~f:(fun ns ->
      let yeses = Map.count ~f:(function Yes -> true | No -> false) ns in
      { Election_status.yes = yeses; no = Map.length ns - yeses })

  let check (e : Error.t) b = if b then Ok () else Error e

  let add_vote s ((statement : Statement.t), proof) =
    let open Result.Let_syntax in
    let nullifiers =
      match Map.find s.nullifiers statement.election with
      | None -> Nullifier.Map.empty
      | Some ns -> ns
    in
    match Map.add nullifiers ~key:statement.nullifier ~data:statement.vote with
    | `Ok nullifiers ->
      let%map () =
        Result.all_unit
          [ check Invalid_proof (Statement.verify statement proof
              ~verification_key:s.config.verification_key)
          ; check Merkle_root_mismatch
              (Hash.equal statement.voters_root s.config.voters_root)
          ]
      in
      { s with nullifiers = Map.set s.nullifiers ~key:statement.election ~data:nullifiers }
    | `Duplicate ->
      Error Duplicate_nullifier
end
