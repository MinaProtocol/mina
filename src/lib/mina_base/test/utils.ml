open Core_kernel

module type HASHABLE = sig
  module Hash : Equal.S

  type t [@@deriving equal, sexp]

  val hash : t -> Hash.t

  val gen : t Quickcheck.Generator.t
end

let hashes_well_behaved (module T : HASHABLE) () =
  let open T in
  Quickcheck.test ~trials:1000
    Quickcheck.Generator.(tuple2 gen gen)
    ~f:
      ([%test_pred: t * t] (fun (a, b) ->
           Bool.equal (equal a b) (Hash.equal (hash a) (hash b)) ) )
