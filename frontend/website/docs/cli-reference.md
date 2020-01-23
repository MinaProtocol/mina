# CLI Reference

!!! warning
    this document is out of date. Refer to the CLI help built into the executable.

The Coda CLI (command-line interface) is the primary way for users to interact with the Coda network. It provides standard client functionality to create accounts, send transactions, and participate in consensus. There are also advanced client and daemon commands for power users.

The CLI is installed as part of the Coda bundle, and can be accessed from a shell by beginning a statement with `coda`. 

!!! warning
    Coda APIs are still under construction, so these commands will likely change

### Commands

`client` - Lightweight client commands - eg. creating an account or sending a transaction

    $ coda client SUBCOMMAND

    === subcommands ===

      get-balance       Get balance associated with a public key
      send-payment      Send payment to an address
      generate-keypair  Generate a new public-key/private-key pair
      delegate-stake    Change the address to which you're delegating your coda
      generate-receipt  Generate a receipt for a sent payment
      verify-receipt    Verify a receipt of a sent payment
      stop-daemon       Stop the daemon
      status            Get running daemon status
      help              explain a given subcommand (perhaps recursively)

`advanced` - Advanced client commands (intended for Coda power users)

    $ coda advanced SUBCOMMAND

    === subcommands ===

      batch-send-payments        Send multiple payments from a file
      constraint-system-digests  Print MD5 digest of each SNARK constraint
      dump-keypair               Print out a keypair from a private key file
      dump-ledger                Print the ledger with given merkle root as a sexp
      get-nonce                  Get the current nonce for an account
      get-public-keys            Get public keys
      get-trust-status           Get the trust status associated with an IP address
      get-trust-status-all       Get trust statuses for all peers known to the trust system
      reset-trust-status         Reset the trust status associated with an IP address
      snark-job-list             List of snark jobs in JSON format
      start-tracing              Start async tracing to $config-directory/$pid.trace
      status-clear-hist          Clear histograms reported in status
      stop-tracing               Stop async tracing
      visualization              Visualize data structures special to Coda
      wrap-key                   Wrap a private key into a private key file
      help                       explain a given subcommand (perhaps recursively)

`daemon` - Daemon commands to configure settings related to how node interacts with network

    $ coda daemon 

    === flags ===

    [-background]                               Run process on the background
    [-bind-ip IP]                               IP of network interface to use
    [-client-port PORT]                         Client to daemon local
                                                communication (default: 8301)
    [-config-directory DIR]                     Configuration directory
    [-external-ip IP]                           External IP address for other
                                                nodes to connect to. You only need
                                                to set this if auto-discovery
                                                fails for some reason.
    [-external-port PORT]                       Base server port for daemon TCP
                                                (discovery UDP on port+1)
                                                (default: 8302)
    [-from-genesis]                             Indicating that we are starting
                                                from genesis or not
    [-limit-concurrent-connections true|false]  Limit the number of concurrent
                                                connections per IP address
                                                (default:true)
    [-log-json]                                 Print daemon log output as JSON
                                                (default: plain text)
    [-log-level Set]                            daemon log level (default: Warn)
    [-peer HOST:PORT]                           TCP daemon communications (can be
                                                given multiple times)
    [-block-producer-key KEYFILE]               Private key file for the proposing
                                                transitions. You cannot provide
                                                both `block-producer-key` and
                                                `block-producer-pubkey`.
                                                (default:don't propose)
    [-block-producer-pubkey PUBLICKEY]          Public key for the associated
                                                private key that is being tracked
                                                by this daemon. You cannot provide
                                                both `block-producer-key` and
                                                `block-producer-pubkey`. (default:
                                                don't propose)
    [-rest-port PORT]                           local REST-server for daemon
                                                interaction (default no
                                                rest-server)
    [-run-snark-worker PUBLICKEY]               Run the SNARK worker with this
                                                public key
    [-snark-worker-fee FEE]                     Amount a worker wants to get
                                                compensated for generating a snark
                                                proof (default: 1)
    [-tracing]                                  Trace into
                                                $config-directory/$pid.trace
    [-unsafe-track-block-producer-key]          Your private key will be copied to
                                                the internal wallets folder
                                                stripped of its password if it is
                                                given using the `block-producer-key`
                                                flag. (default:don't copy the
                                                private key)
    [-work-selection seq|rand]                  Choose work sequentially (seq) or
                                                randomly (rand) (default: seq)
    [-help]                                     print this help text and exit
                                                (alias: -?)

`version` - Print out client version information

    $ coda version
    Commit <...> on branch <...>

`help` - Print out subcommands and explanations

    $ coda -help
    Coda
    
      coda SUBCOMMAND
    
    === subcommands ===
    
      client                      Lightweight client commands
      daemon                      Coda daemon
      internal                    Internal commands
      parallel-worker             internal use only
      transaction-snark-profiler  transaction snark profiler
      version                     print version information
      help                        explain a given subcommand (perhaps recursively)

### Client Subcommands

`get-balance` - Get balance associated with a public key

    $ coda client get-balance 

    === flags ===

      -address PUBLICKEY   Public-key for which you want to check the balance
      [-daemon-port PORT]  Client to daemon local communication (default: 8301)
      [-help]              print this help text and exit
                          (alias: -?)

`send-payment` - Send payment to a public key

    $ coda client send-payment 

    === flags ===

      -amount VALUE        Payment amount you want to send
      -privkey-path FILE   File to read private key from
      -receiver PUBLICKEY  Public key address to which you want to send money
      [-daemon-port PORT]  Client to daemon local communication (default: 8301)
      [-fee FEE]           Amount you are willing to pay to process the transaction
                          (default: 2)
      [-help]              print this help text and exit
                          (alias: -?)

`generate-keypair` - Generate a new public / private key pair

    $ coda client generate-keypair 

    === flags ===

        -privkey-path FILE  File to write private key into (public key will be
                            FILE.pub)
        [-help]             print this help text and exit
                            (alias: -?)

`delegate-stake` - Change the address to which you're delegating your coda

    $ coda client delegate-stake 

    === flags ===

      -delegate PUBLICKEY  Public key address to which you want to which you want to
                          delegate your stake
      -privkey-path FILE   File to read private key from
      [-daemon-port PORT]  Client to daemon local communication (default: 8301)
      [-fee FEE]           Amount you are willing to pay to process the transaction
                          (default: 2)
      [-help]              print this help text and exit
                          (alias: -?)

`generate-receipt` - Generate a receipt for a sent payment

    $ coda client generate-receipt 

    === flags ===

      -address PUBLICKEY               Public-key address of sender
      -receipt-chain-hash RECEIPTHASH  Receipt-chain-hash of the payment that you
                                      want to
                                      generate a receipt for
      [-daemon-port PORT]              Client to daemon local communication
                                      (default: 8301)
      [-help]                          print this help text and exit
                                      (alias: -?)

`verify-receipt` - Verify a receipt of a sent payment

    $ coda client verify-receipt 

    === flags ===

      -address PUBLICKEY         Public-key address of sender
      -payment-path PAYMENTPATH  File to read json version of verifying payment
      -proof-path PROOFFILE      File to read json version of payment receipt
      [-daemon-port PORT]        Client to daemon local communication (default:
                                8301)
      [-help]                    print this help text and exit
                                (alias: -?)

`stop-daemon` - Stop the daemon

    $ coda client stop-daemon 

    === flags ===

      [-daemon-port PORT]  Client to daemon local communication (default: 8301)
      [-help]              print this help text and exit
                          (alias: -?)

`status` - Get running daemon status

    $ coda client status 

    === flags ===

      [-daemon-port PORT]  Client to daemon local communication (default: 8301)
      [-json]              Use json output (default: plaintext)
      [-performance]       Include performance histograms in status output (default:
                          don't include)
      [-help]              print this help text and exit
                          (alias: -?)

`help` - Print out client subcommands and explanations

### Advanced Client Subcommands

`batch-send-payments` - Send multiple payments from a file

    $ coda advanced batch-send-payments PAYMENTS-FILE

    === flags ===

      -privkey-path FILE   File to read private key from
      [-daemon-port PORT]  Client to daemon local communication (default: 8301)
      [-help]              print this help text and exit
                          (alias: -?)

`constraint-system-digests` - Print MD5 digest of each SNARK constraint

    $ coda advanced constraint-system-digests 

    === flags ===

      [-help]  print this help text and exit
              (alias: -?)
              
`dump-keypair` - Print out a keypair from a private key file

    $ coda advanced dump-keypair 

    === flags ===

      -privkey-path FILE  File to read private key from
      [-help]             print this help text and exit
                          (alias: -?)

`dump-ledger` - Print the ledger with given merkle root as a sexp

    $ coda advanced dump-ledger STAGED-LEDGER-HASH

    === flags ===

      [-daemon-port PORT]  Client to daemon local communication (default: 8301)
      [-help]              print this help text and exit
                          (alias: -?)

`get-nonce` - Get the current nonce for an account

    $ coda advanced get-nonce 

    === flags ===

      -address PUBLICKEY   Public-key address you want the nonce for
      [-daemon-port PORT]  Client to daemon local communication (default: 8301)
      [-help]              print this help text and exit
                          (alias: -?)

`get-public-keys` - Get public keys

    $ coda advanced get-public-keys 

    === flags ===

      [-daemon-port PORT]  Client to daemon local communication (default: 8301)
      [-json]              Use json output (default: plaintext)
      [-with-balances]     Show corresponding balances to public keys
      [-help]              print this help text and exit
                          (alias: -?)

`get-trust-status` - Get the trust status associated with an IP address

    $ coda advanced get-trust-status 

    === flags ===

      -ip-address IP       An IPv4 or IPv6 address for which you want to query the
                          trust status
      [-daemon-port PORT]  Client to daemon local communication (default: 8301)
      [-json]              Use json output (default: plaintext)
      [-help]              print this help text and exit
                          (alias: -?)

`get-trust-status-all` - Get trust statuses for all peers known to the trust system

    $ coda advanced get-trust-status-all 

    === flags ===

      [-daemon-port PORT]  Client to daemon local communication (default: 8301)
      [-json]              Use json output (default: plaintext)
      [-nonzero-only]      Only show trust statuses whose trust score is nonzero
      [-help]              print this help text and exit
                          (alias: -?)

`reset-trust-status`- Reset the trust status associated with an IP address

    $ coda advanced reset-trust-status 

    === flags ===

      -ip-address IP       An IPv4 or IPv6 address for which you want to reset the
                          trust status
      [-daemon-port PORT]  Client to daemon local communication (default: 8301)
      [-json]              Use json output (default: plaintext)
      [-help]              print this help text and exit
                          (alias: -?)

`snark-job-list`- List of snark jobs in JSON format

    $ coda advanced snark-job-list 

    === flags ===

      [-daemon-port PORT]  Client to daemon local communication (default: 8301)
      [-help]              print this help text and exit
                          (alias: -?)

`start-tracing` - Start async tracing to $config-directory/$pid.trace

    $ coda advanced start-tracing 

    === flags ===

      [-daemon-port PORT]  Client to daemon local communication (default: 8301)
      [-help]              print this help text and exit
                          (alias: -?)

`status-clear-hist` - Clear histograms reported in status


    $ coda advanced status-clear-hist 

    === flags ===

      [-daemon-port PORT]  Client to daemon local communication (default: 8301)
      [-json]              Use json output (default: plaintext)
      [-performance]       Include performance histograms in status output (default:
                          don't include)
      [-help]              print this help text and exit
                          (alias: -?)

`stop-tracing` - Stop async tracing

    $ coda advanced stop-tracing 

    === flags ===

      [-daemon-port PORT]  Client to daemon local communication (default: 8301)
      [-help]              print this help text and exit
                          (alias: -?)

`visualization` - Visualize data structures special to Coda

    $ coda advanced visualization SUBCOMMAND

    === subcommands ===

      registered-masks     Produce a visualization of the registered-masks
      transition-frontier  Produce a visualization of the transition-frontier
      help                 explain a given subcommand (perhaps recursively)

`wrap-key` - Wrap a private key into a private key file

    $ coda advanced wrap-key 

    === flags ===

      -privkey-path FILE  File to write private key into (public key will be
                          FILE.pub)
      [-help]             print this help text and exit
                          (alias: -?)

`help` - explain a given subcommand (perhaps recursively)

    $ coda advanced SUBCOMMAND

    === subcommands ===

      batch-send-payments        Send multiple payments from a file
      constraint-system-digests  Print MD5 digest of each SNARK constraint
      dump-keypair               Print out a keypair from a private key file
      dump-ledger                Print the ledger with given merkle root as a sexp
      get-nonce                  Get the current nonce for an account
      get-public-keys            Get public keys
      get-trust-status           Get the trust status associated with an IP address
      get-trust-status-all       Get trust statuses for all peers known to the trust
                                system
      reset-trust-status         Reset the trust status associated with an IP
                                address
      snark-job-list             List of snark jobs in JSON format
      start-tracing              Start async tracing to $config-directory/$pid.trace
      status-clear-hist          Clear histograms reported in status
      stop-tracing               Stop async tracing
      visualization              Visualize data structures special to Coda
      wrap-key                   Wrap a private key into a private key file
      help                       explain a given subcommand (perhaps recursively)
