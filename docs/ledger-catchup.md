## Ledger_catchup
This file provides a basic overview of how `src/lib/ledger_catchup/ledger_catchup.ml` works.

### Summary
The main `run` function will take a catchup job from the job reader. Then it will download the missing hashes connecting transition frontier to the target one from network peers. With the hash values, it will do an initial verification and download the transitions. If the number of transitions exceeds the `maximum_download_size`, it will seperate them into chunks and download them in parallel. After that, breadcrumbs are built also in chunks. It will then combine all chunks of breadcrumbs together into a single pipe job and add it to the breadcrumbs pipe.