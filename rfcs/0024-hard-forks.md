## Summary
[summary]: #summary

This RFC describes a system for planning and enacting hard forks.

## Motivation

[motivation]: #motivation

Whenever we make a change to the protocol that changes the rules of consensus or
the state transition system, the network must switch to the new system
atomically, and on all nodes simultaneously. Changes of this sort include for
example modifying the parameters of the parallel scan, making them dynamic,
adding smart contracts, adding shielded transactions/accounts, modifying or
replacing Codaborous, and many others.

Changes that do *not* require hard forks include changes to the network
protocol but not the underlying state machine, and anything that doesn't affect
other nodes. We may want to do a hard fork anyway in some of these situations to
force users to upgrade, especially if the changes are not backwards compatible
or are very important security improvements.

If a change of the first sort were not implemented atomically and at a
coordinated time, there would an unintentional fork: nodes supporting the new
version would generate and accept blocks with the new specification, and nodes
not supporting it would generate and accept blocks with the old one. To prevent
this we plan the fork in advance, and make sure out of date clients stop working
if they are not updated in time.

## Detailed design

[detailed-design]: #detailed-design

I'll call a period of time where one state machine/consensus system is in force
an *era*, to make clear the distinction between them and protocol versions and
epochs. Era zero is the one that is in force at the launch of a network, era one
follows after the first hard fork, and so on. Transitions between eras occur at
a pre-specified time - all blocks with a global slot that begins at or after the
specified era start time and before the era end time will follow the consensus
rules of that era. An *era transition block* is the first block of a new era. If
the parallel scan state is changing or for some other reason we need it, there
may be a special intermediate state. See below for details.

I'll separate the considerations in this RFC into "human" considerations and
"technical" ones. Human considerations refers to how the process should work for
us as we plan, test, and execute the forks. Technical considerations refers to
how the forks will be implemented in the client.

### Human considerations

There are two types of hard forks to consider, with different needs: upgrades,
and emergency fixes. Upgrades can and should be scheduled well in advance, while
emergency fixes may need to be deployed on the scale of days.

Upgrades will happen twice per year, on the first Tuesday of March at 00:00:00
UTC and the first Tuesday of October at 00:00:00 UTC. Clients that do not
include support for a scheduled fork will **halt all progress** at that slot.
This ensures out of date clients don't continue on a mostly dead and therefore
vulnerable network. Client that do support the upgrade will, of course, execute
the transition at that time/slot.

Mistakes in hard forks can be very bad, but are not intrinsically more dangerous
than client upgrades. However, they are more dangerous in that nodes that do not
upgrade could end up on a dead fork without realizing it. An on-chain signaling
mechanism for upcoming hard forks would mitigate this problem, but I'm not sure
there's a good way to do that. See below section.

Because mistakes may be catastrophic and upgrades may involve large changes,
this process is very conservative. The timeline will be as follows:

1. Beginning of previous era:
  * Discussion, design and implementation of features for next era begins. This
    can happen in parallel for different features, and should be mostly done
    before the finalization process begins.
1. Six weeks from era start:
  * A public testnet starts, forked off the mainnet at the current block. At
    this point it has no changes from the previous era, other than being
    segregated. This will be used as a dry-run for the upcoming fork. We may
    need to modify delegations in order to ensure sufficient stake is online.
  * Feature specification lock. All features proposed to go into this hard fork
    have been submitted to the RFC process. Everything submitted must have a
    working, tested implementation.
2. Five weeks from era start:
  * All proposals are accepted or rejected/pushed to the next era.
3. Four weeks from era start:
  * Testnet era advances and the new features begin the final burn-in test.
    Builds should be available implementing everything, at a "release candidate"
    level of quality.
  * The Coda team and general public monitor the testnet, use it, and try to
    break it.
4. Up until one week from era start:
  * For every issue we discover, if fixing it would require another hard fork we
    disable the associated feature unless the change is very simple. Disabling a
    feature requires starting a new era on the testnet. If fixing it is only a
    code change we're a little more lenient: if the fix is minor we make it and
    continue, if it's major we still drop the feature. In extreme situations,
    where disabling an individual feature is not possible or advisable, we may
    abort the upgrade entirely, releasing new clients that extend the current
    era up to the next date.
5. One week from era start:
  * Mainnet client builds that support the new era are released and all nodes
    are expected to upgrade. If no further intervention occurs the transition
    will proceed as planned.
  * No further changes are allowed. If a bug that should block era transition is
    found we delay the era start by another week, releasing new clients, and
    return to step 4.
6. Era start:
  * All changes are active on the mainnet and the burn-in testnet is retired.
    Pop the confetti.

For emergency fixes the procedure is much shorter. Anything that threatens
security of funds, network liveness, or consistency counts as an emergency. We
could also do emergency forks to revert thefts or loss of funds due to error,
as in Ethereum's [DAO fork](https://eips.ethereum.org/EIPS/eip-779), but whether
and when to do that is outside the scope of this RFC.

Timeline:
1. The underlying issue is discovered and documented. The Coda team decides an
   emergency hard fork is necessary.
2. We schedule the new era, for some time in the near future e.g. 48 hours from
   now. We release new client versions that halt after the next scheduled era
   starts. This reduces the chance a client will be stuck on a dead network. If
   the fix is very simple we can skip this.
3. We write and test the fix, then release new builds, with the new era
   programmed in.
4. The new era begins.

If an emergency fix is done in the six weeks prior to a scheduled upgrade, the
upgrade will be delayed such that the new era starts seven weeks after the
hotfix era does - with the six week process above beginning one week after the
hotfix era starts to give us some buffer.

### Technical considerations

#### Distinguishing blocks from different eras

We extend each block with an `era_id` field, which is a 32 bit integer. Each ID
is used at most once, and corresponds to a specific set of features. They are
not necessarily sequential, and are distinct from era numbers, which are. If we
change what features are in a particular era, we use a new ID. Each client
executable includes the set of global slot interval to era id mappings, and
checks that every block it accepts has the appropriate era id for its slot. The
blockchain SNARK certifies that the current and prior era IDs are correct. A
block with a global slot that has no corresponding era ID is invalid.

#### Feature flags

In order to develop different features in parallel and avoid having painful long
lived branches, we'll adopt feature flags for blocks and transactions. This is
essential for disabling individual features that aren't ready yet without
breaking other code or requiring extensive repo surgery.

Feature flags will be determined statically, and the changes to types will be
enforced by the type system, using a system inspired by Trees That Grow. This
allows us to easily change which features are enabled, and express in the type
system which functions do and don't interact with particular features. A sketch
of how this will work, using GADTs:

```ocaml

(** Type level booleans *)
type true_ty = Mk_true
type false_ty = Mk_false

module Static_option = struct
  type (_, _) t =
   | SSome : 'a -> (true_ty, 'a) t
   | SNone : (false_ty, 'a) t

  let get : ('true_ty, 'a) t -> 'a = function SSome a -> a

  let map : type e. f:('a -> 'b) -> (e, 'a) t -> (e, 'b) t = fun ~f -> function
     | SSome x -> SSome (f x)
     | SNone -> SNone

  let elim : type e. f:('a -> 'b) -> 'b -> (e, 'a) t -> 'b = fun ~f def ->
    function
      | SSome x -> f x
      | SNone -> def
end

module Static_either = struct
  type (_,_,_) t =
    | SLeft : 'a -> (false_ty, 'a, 'b) t
    | SRight : 'b -> (true_ty, 'a, 'b) t

  let get_l : (false_ty, 'a, _) t -> 'a = function SLeft a -> a

  let map_l : f:('a -> 'b) -> (false_ty, 'a, 'c) t -> (false_ty, 'b, 'c) t =
    fun ~f -> function
      | SLeft a -> SLeft (f a)

  let get_r : (true_ty, _, 'a) t -> 'a = function SRight a -> a

  let map_r : f:('b -> 'c) -> (true_ty, 'a, 'b) t -> (true_ty, 'a, 'c) t =
    fun ~f -> function
      | SRight a -> SRight (f a)

  let bimap :
    type w. f:('a -> 'c) -> g:('b -> 'd) -> (w, 'a, 'b) t -> (w, 'c, 'd) t =
    fun ~f ~g -> function
      | SLeft a -> SLeft (f a)
      | SRight b -> SRight (g b)

  let elim : f:('a -> 'c) -> g:('b -> 'c) -> (_, 'a, 'b) t -> 'c = fun ~f ~g ->
    function
      | SLeft a -> f a
      | SRight a -> g a
end

(** A block structure with a transaction counter and possible change to the
    parallel scan data structure, configured with feature flags. *)
module Block = struct
  type ('has_transaction_counter, 'use_new_pscan) t =
    {epoch : int;
     slot : int;
     era_id : int;
     transaction_counter : ('has_transaction_counter, int) Static_option.t;
     pscan : ('use_new_pscan, Old_pscan.t, New_pscan.t) Static_either.t
    }

  type era_id_0 = (false_ty, false_ty) t
  type era_id_1 = (false_ty, true_ty)  t
  type era_id_2 = (true_ty,  true_ty)  t

  type existential =
    | Era0 : era_id_0 -> existential
    | Era1 : era_id_1 -> existential
    | Era2 : era_id_2 -> existential
end

let incr_count : (true_ty, 'a) Block.t -> (true_ty, 'a) Block.t = fun b ->
  {b with transaction_counter =
    Static_option.map ~f:(fun x -> x + 1) b.transaction_counter
  }

(** Update the parallel scan state, dispatching on which one is turned on. A
    separate function would handle generating a block that is an era transition.
*)
let update_pscan :
  type use_new_pscan.
  ('htc, use_new_pscan) Block.t -> ('htc, use_new_pscan) Block.t = fun b ->
   match b.pscan with
   (* The type system prevents us from calling Old_pscan.update on a
      block with the new data structure and vice versa. *)
     | SLeft ps -> Old_pscan.update b
     | SRight ps -> New_pscan.update b
```

Blocks that come from or are sent to the network will be (de)serialized via
`Block.existential`. This scheme will unfortunately require writing some
serialization code manually or modifying the `bin_prot` ppx.

To keep the number of type parameters small and mitigate the combinatorial
explosion of possible configurations, as time passes we'll remove type
parameters that are set to the same value in all currently supported eras (now +
the next one) and change the types of the associated fields to directly include
the values.

#### Handling changes in types

Different kinds of changes will have to be implemented differently. If types
from a new era only add optional fields, or new fields that have a reasonable
default, then we can convert incoming data from era n into the era n+1 version,
and only store the items with the type parameterization of the current era. If
this isn't possible then we will have to either have both options in an
`Either.t` or in some cases two parallel data structures.

##### Blocks + block components

If there is no or a small enough change to the consensus mechanism then the
transition frontier can have blocks of both types, or blocks of only the new
type with conversion. A sufficiently different consensus mechanism might need a
separate transition frontier or other data structure to support it. In that
case, blocks from era n will go in the old transition frontier and blocks from
era n+1 will go into the new structure. The era transition block will be a
special case.

##### User transactions

As of now our rule is that we only accept transactions into the pool if they
could be applied to the best tip. Continuing in this vein, we will only accept
transactions into the pool if they are valid in the current era. This will cause
a small hiccup in throughput when era transitions happen, but that's acceptable
since they are rare.

##### Ledger SNARKs

We also do not accept ledger SNARKs until we've entered the appropriate era for
them and there is a block whose children might need to buy them.

#### Signaling support for the next era

We would like to have a mechanism that lets users know if they're out of date,
and forces them to update/informs them they are or will soon be on a dead
network. Block producers could include the next era id and transition slot in
every block, but there is no incentive to be truthful, so I'm not convinced the
feature is actually all that useful. Checking an HTTP endpoint operated by O(1)
would work, though it's more centralized than I'd like. (Coda needs to continue
working if everyone who works here dies and the Bay Area falls into the sea.)

We could also have accounts or block producers vote on-chain whether to move to
a new era. End users will generally prefer the system to be hands-off, and it
simplifies development not to have it.

#### Parallel scan transitions

It would be easiest to deal with changes to the parallel scan state or the
SNARKs within it if it were drained and restarted cleanly when necessary. This
would simplify things a lot and mean that the merge SNARKs didn't have to be
able to verify both old and new proofs. Below is a scheme to do this. The
disadvantage is that it requires effectively pausing progress while this
happens, and induces its own complexity.

We add a new, special, transaction type, a no-op. These don't do anything but
take up space in the scan, and in particular they don't ever require a base or
merge SNARK to be built. Taking up space in the scan means that SNARKs for past
transactions have to be bought to include them. Observe that if all the
transactions in the scan state are no-ops then discarding it is safe.

If an era transition involves a parallel scan change, the clients will follow
the following process:

1. At the era start slot we enter a transition period, and do not actually begin
   using the new system. The first part of this period is RED.
2. RED: no new user transactions are allowed, and each new block must include as
   many no-ops as will fit, after valid coinbases and fee transfers. Because
   block producers aren't collecting transaction fees anymore, but are still
   paying for ledger proofs, we need to add an incentive to make sure blocks are
   still produced in this period. To that end, the coinbase amount will double
   every 10 slots (actual constants TBD). This phase continues until the only
   items in the scan state are no-ops, coinbases, and fee transfers.
3. ORANGE: At this point you only need to add three SNARKs per block: one
   coinbase, one fee transfer, and one merge. To clear the last bit we have to
   abandon using the parallel scan entirely. You can't empty it if you're adding
   a coinbase to it every block. In this phase, coinbases and fee transfers can
   no longer be added to the scan state, and we add a single extra ledger proof,
   built sequentially, to the block data. This is a proof of the ledger state
   transition to be applied after everything in the scan state. The block
   producers themselves will need to create these. Block creation is otherwise
   normal, but any necessary coinbases and fee transfers are merged into the
   extra proof. Note this means that building these SNARKs must be possible in
   less than one slot's time. It doesn't, however, have to be efficient to do
   so, since this is a rare and specially incentivized situation.

   For concreteness: suppose it's the first block of the orange phase. Let S_n
   be the state hash after all transactions in the scan state are applied. When
   Alice creates a block, she buys three SNARKs, and pays herself with a
   coinbase. She builds base proofs for the necessary coinbase and fee transfer
   transactions, and then a merge proof of those. The statement is S_n -> S_n+2.
   In the following block(s), Bob only needs to buy one SNARK bundle to continue
   draining the scan state, since he's not adding transactions to it anymore. He
   creates a coinbase to pay himself, and it has room for the single fee
   transfer he needs. He builds a base proof of that with statement S_n+2 ->
   S_n+3, and a merge proof using the previous one with statement S_n -> S_n+3.
   This process continues until the scan state is empty and a snarked ledger
   proof up to S_n is emitted. The final block of the orange phase applies the
   sequentially built snark, giving us a valid era n block with a ledger that
   includes all transactions up to now.
4. GREEN: we may now create an era n+1 block, with an empty (new-style) scan
   state, starting from the correct state hash. Coinbase amounts go back to
   normal.

#### Checking blockchain SNARKs from prior eras

The part of the blockchain SNARK that verifies the previous blockchain SNARK
will choose which verification key to use depending on the global slot of the
previous block, along with whether era end finalization has finished. This will
require adding fields to `Blockchain_state` and `Consensus_state`. A circuit for
era n only references the verification keys for era n and era n-1, it can't
check older SNARKs.

## Drawbacks
[drawbacks]: #drawbacks

This will be a lot of work to implement, and complicates many pieces of Coda.
We'll have to write some serialization logic manually, type hackery is always a
mixed blessing, we'll add another way to add ledger proofs, and in general it
enlarges the attack and bug surface. But we'll pay complexity costs for hard
forks at some point and it'll be much nicer to do it ahead of time.

## Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

* Why is this design the best in the space of possible designs?
  This design is quite conservative in process design, and pays a pretty large
  complexity cost up front to simplify future work. Cryptocurrency is not a
  space where we can "move fast and break things", so the conservative end of
  the spectrum is where we should be aiming. The complexity cost is justified by
  simplifying transitions and operation within eras.
* What other designs have been considered and what is the rationale for not choosing them?
  * We could not have a fixed schedule, and simply do protocol upgrades "when
    they're done". I like the regular schedule because it's a strong incentive
    to make smaller changes, and ensure they actually get shipped regularly.
  * Rather than doing the fancy type level feature flags, we could put booleans
    and optional fields into the data structures. This would reduce the amount
    of time we spend fighting the type checker, and reduce the knowledge burden
    to work on the codebase, but the type level flags make the code more
    readable and more reliable.
  * We could not have the parallel scan drain and restart process, instead
    simply keeping both versions as part of the block data, only removing from
    the old one and only adding to the new one. This is the more obvious method,
    but it's more complex in the steady state, and easier to get wrong. Fully
    discarding the old state means we can entirely forget about the prior era's
    design when writing code for the next era, and not have to worry about
    accidentally mixing up which data structure we're supposed to do what with.
  * The incentives in the parallel scan transition process could be different.
    If we're confident that the coinbases are sufficient to buy all the snarks
    needed for draining then we could leave the value as is. That would be
    simpler, but I'm not confident, and it becomes less and less likely as the
    transaction capacity increases. Or, instead of messing with the coinbase
    amounts, we could award transaction fees for no-ops out of dilution, based
    on a moving average of prior transaction fees. This would be more
    straightforward, but block producers can manipulate the average by issuing
    fake transactions and paying themselves fees. This would eat up slots for
    real transactions, and make payouts uncertain for block producers.
* What is the impact of not doing this?
  Doing a hard fork at some point in the future is inevitable, we need a way to
  do it. We could skip this whole design and just deal with the problems in the
  future, but it'll be much more awkward.

## Prior art
[prior-art]: #prior-art

Discuss prior art, both the good and the bad, in relation to this proposal.

The release months are taken from Ubuntu's schedule, months 4 and 10, chosen to
avoid too many nearby holidays. There are two draft status Ethereum EIPs,
[233](https://eips.ethereum.org/EIPS/eip-233) and
[1872](https://eips.ethereum.org/EIPS/eip-1872) that propose a release timeline
and schedule. They're broadly similar, though the proposed schedule in EIP 1872
has more frequent updates and PoW means they have to choose a block number and
not a specific time.

Cosmos Hub / ATOM does protocol upgrades involve a manual process wherein
validators must shut down the old client, take a snapshot of the ledger state,
then import that into the new client. See
[here](https://github.com/cosmos/gaia/blob/master/docs/migration/cosmoshub-2.md).
Gross. We want the process to happen automatically, and ideally be smooth enough
that most people don't notice anything.

## Unresolved questions
[unresolved-questions]: #unresolved-questions

* What parts of the design do you expect to resolve through the RFC process before this gets merged?
   * During parallel scan transitions, what should the rate of coinbase amount
     increase actually be? How much stakes does a selfish block producer need to
     have for it to be profitable in expectation for them to not produce a block
     and increase their future rewards. Can we tune the constants to make that
     scenario impossible under our modeling assumptions?
   * Is the biannual frequency right? More frequent upgrades would let us ship
     things sooner, but would reduce the amount of time to work on large
     features and increase the effort required organizing these things.
* What parts of the design do you expect to resolve through the implementation of this feature before merge?
* What related issues do you consider out of scope for this RFC that could be addressed in the future independently of the solution that comes out of this RFC?
