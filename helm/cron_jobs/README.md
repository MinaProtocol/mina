Replayer cron jobs
==================

There are replayer cron jobs for mainnet, devnet, and berkeley. These
jobs are run daily, to replay a day's worth of transactions.

Each cron job downloads the most recent archive dump corresponding to
a network, and loads the data into Postgresql. That results in an
archive database. The most recent replayer checkpoint file is
downloaded, which provides the starting point for the replayer. When
the replayer runs, it creates new checkpoint files every 50
blocks. When the replayer finishes, it uploads the most recent
checkpoint file, so it can be used in the following day's run. If
there are any errors, the replayer logs are also uploaded.

There is a separate checkpoint file bucket for each network.  Both the
checkpoint files and error files for a given network are uploaded to
the same bucket.
