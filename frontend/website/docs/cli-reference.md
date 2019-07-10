# CLI Reference

!!! warning
    Coda APIs are still under construction, so these commands may change

$ coda.exe -help
    Coda
    
      coda.exe SUBCOMMAND
    
    === subcommands ===
    
      client                      Lightweight client commands
      daemon                      Coda daemon
      internal                    Internal commands
      parallel-worker             internal use only
      transaction-snark-profiler  transaction snark profiler
      version                     print version information
      help                        explain a given subcommand (perhaps recursively)

## Client

    $ coda.exe client -help
    Lightweight client commands
    
      coda.exe client SUBCOMMAND
    
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

## Daemon

    $ coda.exe daemon -help
    Coda daemon
    
      coda.exe daemon 
    
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
      [-propose-key KEYFILE]                      Private key file for the proposing
                                                  transitions. You cannot provide
                                                  both `propose-key` and
                                                  `propose-public-key`.
                                                  (default:don't propose)
      [-propose-public-key PUBLICKEY]             Public key for the associated
                                                  private key that is being tracked
                                                  by this daemon. You cannot provide
                                                  both `propose-key` and
                                                  `propose-public-key`. (default:
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
      [-unsafe-track-propose-key]                 Your private key will be copied to
                                                  the internal wallets folder
                                                  stripped of its password if it is
                                                  given using the `propose-key`
                                                  flag. (default:don't copy the
                                                  private key)
      [-work-selection seq|rand]                  Choose work sequentially (seq) or
                                                  randomly (rand) (default: seq)
      [-help]                                     print this help text and exit
                                                  (alias: -?)