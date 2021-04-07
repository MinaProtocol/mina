# Merkle ledgers

A Merkle ledger is essentially a binary tree with a fixed depth, whose
leaves contain account data. Each node in the tree has an associated
hash and from those node hashes, a Merkle root can be
computed. Ledgers also maintain some bookkeeping data stored outside
the binary tree. In Mina, there are several implementations of the
ledger data structure, with some common features.

The basic interface for ledgers is in `Base_ledger_intf.ml`. The items
below help to explain some of the types and terminology mentioned
there.

## Uuids

Each ledger has a unique identifier, to distinguish it from other
ledgers. There is no functional significance for a UUID, other than to
aid in debugging.

## Accounts and account ids

An account is a user account, containing a user's public key, balance,
and other information.  Accounts can be denominated in Mina tokens, or
another token that's been minted. A user with a particular public key
can have distinct accounts denominated in different tokens.

An account id denotes an account with a particular public key and token. Both items are
needed to lookup an account in the ledger.

## Merkle addresses, locations, indexes, directories

The Merkle address of a node is a bitstring describing the path from
the root of the binary tree to that node. The address of the root is
the empty string. A 0 bit denotes choosing the left subtree, a 1 chooses
the right subtree.

An account is stored at a particular location in a ledger. Locations
can also denote hashes at interior nodes. For accounts and hashes, a
location contains an address. A location can also denote where
bookkeeping state information is stored, unrelated to the binary tree
as such.

Besides locations, each account in a ledger has a distinct index,
which is an integer. Indexes are a 0-based integer indicating
the leaf order in the ledger's binary tree.

Some ledger implementations may rely on a file system, with an
associated notion of directories.

## Merkle paths and roots

The Merkle root is the hash at the root of the binary tree, computed
by combining hashes from all nodes in the tree. Hashes are combined
using the function `Mina_base.Ledger_hash.merge`. There's a table that
"salts" the hash computation for each level of the binary tree.

A Merkle path is a path from a location or index, to the root of the
binary tree that represents a ledger. Such a path consists of edges
labeled `Left` or `Right`, and denotes the nodes in the binary whose
hashes are needed to compute the Merkle root, given the hash of the
node at the location or index. The first element of the path is the
sibling of the node at the location or index.  Such a path is
sometimes called a Merkle proof.
