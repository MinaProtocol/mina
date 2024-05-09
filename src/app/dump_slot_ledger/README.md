# Ledger Dumper Tool

## Overview

The Ledger Dumper Tool is queries the archive database for ledger entries associated with a specific slot, which is a unit of time in mina. The data fetched includes various details such as delegate keys, balances, nonces, receipt chain hashes, and more.


## Example

```
dune exec src/app/dump_slot_ledger/dump_slot_ledger.exe -- --slot 3 --postgres-uri postgresql://neptune@localhost:5432/archive
```