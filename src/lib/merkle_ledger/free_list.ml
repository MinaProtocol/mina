module type S = sig
  type t

  type location

  (** {2 Serializers}*)

  val sexp_of_t : t -> Sexp.t

  val t_of_sexp : Sexp.t -> t

  val serialize : ledger_depth:int -> t -> Bigstring.t

  val deserialize : ledger_depth:int -> Bigstring.t -> t

  (** {2 Pretty-printers} *)

  val pp : Format.formatter -> t -> unit

  (** {2 Test generators }*)

  val gen : ledger_depth:int -> t Quickcheck.Generator.t

  val empty : t

  val equal : t -> t -> bool

  val is_empty : t -> bool

  val size : t -> int

  module Location : sig
    val add : t -> location -> t

    val remove : t -> location -> t

    val pop : t -> (location * t) option

    val top : t -> location option

    val mem : t -> location -> bool

    val remove_all_contiguous : t -> location -> t * location option

    val of_list : location list -> t

    val to_list : t -> location list
  end
end

module Make (L : Location_intf.S) : S with type location = L.t = struct
  module Addr = L.Addr

  type location = L.t

  module Set = Set.Make (L.Addr)

  let size = Set.length

  let pp ppf set =
    Format.fprintf ppf "@[<hov>[ %a]@]"
      (fun ppf set -> Set.iter set ~f:(Format.fprintf ppf "%a;@ " Addr.pp))
      set

  (* [remove_all_contiguous set addr] removes all addresses contiguous from
     [a] in decreasing order according to {!val:Location.Addr.prev}.

     @return  a free list where all such addresses have been removed, and the first
     address not in set, if any
  *)
  let rec remove_all_contiguous set addr =
    if Set.mem set addr then
      let set = Set.remove set addr in
      let addr = Addr.prev addr in
      match addr with
      | None ->
          (set, addr)
      | Some addr ->
          remove_all_contiguous set addr
    else (set, Some addr)

  (* This could be made more efficient, especially if we stored the size of the
     set.

     We'd just have to allocate the bigstring of <size> * <addr size> and
     iterate once.

     Instead, iterate 3x (to_list, List.map, Bigstring.concat).
  *)
  let serialize ~ledger_depth t =
    Set.to_list t
    |> List.map ~f:(Addr.serialize ~ledger_depth)
    |> Bigstring.concat

  (* [byte_count_of_bits n] returns how many bytes we need to represent [n] bits *)
  let byte_count_of_bits n = (n / 8) + min 1 (n % 8)

  (* [deserialize] *)
  let deserialize ~ledger_depth bs =
    let bitsize = byte_count_of_bits ledger_depth in
    let len = Bigstring.length bs in
    let rec read acc pos =
      if pos >= len then acc
      else
        let data = Bigstring.sub bs ~pos ~len:bitsize in
        let path = Addr.of_byte_string (Bigstring.to_string data) in
        let addr = Addr.slice path 0 ledger_depth in
        read (addr :: acc) (pos + bitsize)
    in
    let addrs = read [] 0 in
    Set.of_list addrs

  let gen ~ledger_depth =
    let path_gen = Direction.gen_list ledger_depth in
    let addr_gen = Quickcheck.Generator.map path_gen ~f:Addr.of_directions in
    let addrs = Quickcheck.Generator.list addr_gen in
    Quickcheck.Generator.map addrs ~f:Set.of_list

  let top = Set.max_elt

  module Location = struct
    let lift_exn fname f = function
      | L.Account addr ->
          f addr
      | Generic _bigstring ->
          let msg = Printf.sprintf "%s: cannot handle generic location" fname in
          invalid_arg msg
      | Hash _ ->
          let msg = Printf.sprintf "%s: cannot handle hash location " fname in
          invalid_arg msg

    (* The free list should only contain addresses that locate accounts *)
    let add set loc = lift_exn "Free_list.add" (Set.add set) loc

    let remove set loc = lift_exn "Free_list.remove" (Set.remove set) loc

    let account addr = L.Account addr

    let pop set =
      Option.map ~f:(fun addr -> (account addr, Set.remove set addr)) (top set)

    let top set = Option.map ~f:account (top set)

    let mem set loc = lift_exn "Free_list.mem" (Set.mem set) loc

    let of_list locs = List.map locs ~f:(lift_exn "id" Fn.id) |> Set.of_list

    let to_list set = Set.to_list set |> List.map ~f:account

    let remove_all_contiguous set loc =
      let set, addr =
        lift_exn "Free_list.remove_all_contiguous"
          (remove_all_contiguous set)
          loc
      in
      (set, Option.map ~f:account addr)
  end

  include Set
end
