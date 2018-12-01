## Summary
[summary]: #summary

Use [ipfs](https://docs.ipfs.io/) as a content sharing network for history sync. There is also space to use their "gossipsub" pubsub protocol (when it's finished) for efficient broadcasting.

## Motivation

[motivation]: #motivation

As part of the new transition frontier controller ([RFC #8](./0008-transition-frontier-controller.md)), we need to implement "history sync", downloading parts of the history from peers who were online to see it. This is essentially a distributed lookup of breadcrumb by state hash. We currently use a naive algorithm for a similar problem, but it has known limitations. libp2p is the networking code that ipfs uses, which handles things like network transport concerns, NAT traversal, and a DHT. On top of that, ipfs builds a distributed content-addressed data store.

## Detailed design

[detailed-design]: #detailed-design

go-ipfs has an HTTP API. The signature we expose for using it is:

```ocaml
module type Block_storage_intf = sig
  type t

  module Handle : sig
    type t [@@deriving bin_io]
  end

  val create : peers:Peer.t list -> state_dir:string -> listen:Host_and_port.t -> t Deferred.Or_error.t
  (** Start the helper process, listening on external address [listen], using [peers] to bootstrap and storing state in [state_dir]. *)

  val shutdown : t -> unit
  (** Shutdown the helper process *)

  val provide : data:Bigstring.t -> Handle.t Deferred.Or_error.t
  (** Offer a piece of data to the network, giving back a handle that can be used with [fetch].

      This will persist the data in local storage until [remove] is called.
   *)

  val remove : Handle.t -> unit Deferred.Or_error.t
  (** Remove the data referred to by [handle] from local storage and stop offering it to the network. *)

  val fetch : Handle.t -> Bigstring.t Deferred.Or_error.t
  (** Attempt to retrieve a piece of data. *)
end
```

Internally, these are implemented using ipfs's `block` API. Blocks are ipfs's primitive unit of content-addressed data. They have a bittorrent-inspired "bitswap" protocol for exchanging blocks with peers. The three main methods correspond exactly to `block/put`, `block/rm`, and `block/get` respectively. We will spawn and manage our own ipfs daemon that isn't necessarily connected to the wider ipfs network (by not using the default bootstrap list). The provided blocks persist past restarts - the frontier will have to keep track of which blocks it stops caring about and explicitly `remove` them.

ipfs internally uses blocks of size 2¹⁸ (256K). Our blocks are smaller than that, so this interface should be sufficient. For larger information, the higher level object interface (`add`, `pin/rm`, and `get` respectively) automatically splits large files into a merkle DAG of blocks.

Eventually, mobile and web will need to access this information. There are reports that go-ipfs works fine on [iOS](https://discuss.ipfs.io/t/go-ipfs-on-ios/2732) with lowered resource caps. The ARM binaries run fine on Android. There are significant resource usage concerns, though it's not clear yet what the actual penalty is (see [this](https://github.com/ipfs/go-ipfs/issues/4137) or [this](https://github.com/ipfs/notes/issues/68)) For browsers, they can access an external ipfs daemon over the HTTP API. There is a js-ipfs project that we should be able to start using [after they finish implementing the DHT](https://github.com/ipfs/js-ipfs/pull/856).

## Drawbacks
[drawbacks]: #drawbacks

ipfs is a substantial dependency, and includes a lot of functionality we do not need (yet, or ever). A stripped go-ipfs binary is 31MB.

The interface is "nameless" - data is not stored with a name, one is generated. Our uses need to lookup data by a key that isn't necessarily the block hash. In practice this means that we need to keep track of the ipfs block handles alongside the actual hash we care about. Presumably the node giving us the external transition hashes in the first place will also have this information, but it could also be stored in the DHT.

## Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

We could implement this interface without ipfs, using libp2p or our existing DHT/RPC code. The main considerations are tracking which nodes have what block ("content routing") and distributing the download load amongst those nodes.

## Unresolved questions
[unresolved-questions]: #unresolved-questions

ipfs also provides an interface we could use for peer discovery and establishing streams with them. Should we abandon our current DHT entirely and use that? We would get transport security "for free" doing this, and potentially browser compatibility through js-libp2p.

Performance characteristics of this approach are currently unknown. We should run an experiment with a few nodes storing the maximum amount of data we foresee needing and measure memory/disk consumption of each node.

Should we turn on transport security?

Do ipfs peer identities matter at all or can we make new ephemeral keypairs when convenient?