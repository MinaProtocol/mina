(* Hi! This is an annotated example usage of this library, intended to be used as
   a tutorial. *)
(* First we bring [Core] and the [Snark] module into scope, selecting
   the Bn128-based snark. *)
open Core
open Snarky
module Snark = Snark.Make (Snark.Backends.Bn128.Default)
module Knapsack = Knapsack.Make (Snark)
open Snark
open Let_syntax

(* A merkle tree is a data-structure which allows one to publish a "summary"
   (the "root hash" or "merkle hash") of a list of values in such a way that
   one can later prove for a particular value that it was a member of that list.

   There is also a notion of "updating" a merkle tree at a particular index, or address.
   This means replacing the value stored at that address  with a new value.

   In this tutorial, we would like to write a checked computation verifying the following:

   Given:
   - a merkle hash [root_start]
   - a list of pairs [(x_1, addr_1), ..., (x_n, addr_n)]
   - a merkle hash [root_end]

   Prove that updating a merkle tree with root hash [root_start] by
   setting the value at [addr_i] to [x_i] for [i = 1...n] results in
   a merkle tree with root hash [root_end]. *)
(* First, we specify the hash function we use, and the type of hashes.
   We will use the knapsack hash function. *)

let knapsack =
  let dimension = 2 in
  Knapsack.create ~dimension
    ~max_input_length:(2 * Field.size_in_bits * dimension)

module Hash = struct
  include Knapsack.Hash (struct
    let knapsack = knapsack
  end)

  (* Don't do this at home *)
  let hash ~height:_ x y = hash x y
end

(* Second, we specify the type of values which we'll store in the merkle tree.
   Let's say a value is a bitsring of length 10. *)
module Value = struct
  let length = 10

  type var = Boolean.var list

  type value = bool list

  (* This "typ" tells camlsnark how to store a [Value.value] as R1CS variables,
    as well as any constraints to put on the values (in this case boolean constraints.) *)
  let typ : (var, value) Typ.t = Typ.list ~length Boolean.typ

  let random () = List.init length ~f:(fun _ -> Random.bool ())

  let hash (bs : var) = Knapsack.Checked.hash_to_bits knapsack bs
end

module Merkle_tree_checked = Merkle_tree.Checked (Snark) (Hash) (Value)

(* The next thing to do is to specify the input for our snark. *)
let num_pairs = 5

let depth = 10

let address_typ = Merkle_tree_checked.Address.typ ~depth

let input () =
  let open Data_spec in
  [ Hash.typ (* [root_start] *)
  ; Typ.(list ~length:num_pairs (tuple2 Value.typ address_typ))
    (* [(x_1, addr_1), ..., (x_n, addr_n)]  *)
  ; Hash.typ
  (* [root_end] *)
   ]

(* Now, we write the computation that we want our snark to certify.
   A [Checked] computation is paramterized by two types. [Checked.t] is
   a monad, which allows us to use overloaded [let] notation to write verified
   computations in a very natural style.
*)
let update_many root_start
    (updates : (Value.var * Merkle_tree_checked.Address.var) list) root_end :
    ( unit
      (* 1. The return type. Here it is [unit], indicating we return
        only the [unit] value. *)
    , (Hash.value, Value.value) Merkle_tree.t
    (* 2. The prover's state type. Here, we indicate that the prover has
        access to a Merkle tree using hashes of type [Hash.value] and containing
        values of type [Value.value]. *)
    )
    Checked.t =
  (* We loop over all the updates, updating the prover's Merkle tree as we go. *)
  let rec go curr_root = function
    | [] -> return curr_root
    | (x, addr) :: updates' ->
        (* We update the Merkle tree, computing the new Merkle root, and repeat. *)
        let%bind next_root =
          let%bind prev_value =
            (* Here we look up the previously stored value in the Merkle tree so that we can use
            it in authenticating the update. *)
            exists Value.typ
              ~compute:
                As_prover.(
                  map2 ~f:Merkle_tree.get_exn get_state (read address_typ addr))
          in
          Merkle_tree_checked.update addr ~depth ~root:curr_root
            ~prev:prev_value ~next:x
        in
        go next_root updates'
  in
  let%bind final_root = go root_start updates in
  (* Finally, after computing the root after all those updates, we assert that it is
     equal to the specified [root_end]. *)
  Hash.assert_equal final_root root_end

(* Now that we have specified the computation to produce a snark for, we can actually
   produce the snark. *)
(* First we generate the keypair. *)
let keypair = generate_keypair ~exposing:(input ()) update_many

(* Next, we can generate a proof on some sample inputs. *)
(* First the inputs. *)
let tree_start =
  let num_entries = 1 lsl depth in
  let t0 =
    Merkle_tree.create (Value.random ())
      ~hash:(fun xo ->
        Knapsack.hash_to_bits knapsack (Option.value ~default:[] xo) )
      ~compress:(fun x y -> Knapsack.hash_to_bits knapsack (x @ y))
  in
  Merkle_tree.add_many t0
    (List.init (num_entries - 1) ~f:(fun _ -> Value.random ()))

let updates =
  let random_addr () = Random.int (Int.pow 2 depth) in
  List.init num_pairs ~f:(fun _ -> (Value.random (), random_addr ()))

let tree_end =
  List.fold_left updates ~init:tree_start ~f:(fun acc (x, addr) ->
      Merkle_tree.update acc addr x )

let root_start = Merkle_tree.root tree_start

let root_end = Merkle_tree.root tree_end

(* And now the proof. *)
let proof =
  prove (Keypair.pk keypair) (input ()) (* The input spec *)
                                        tree_start
    (* The initial state for the prover *)
    update_many (* The computation to create a snark for *)
                root_start (* The inputs for the snark *)
                           updates root_end

(* Now we can check that the snark verifies as expected. *)
let verified =
  verify proof (Keypair.vk keypair) (input ()) root_start updates root_end

let () = printf "Verified: %b\n" verified
