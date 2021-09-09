# Intro

Compile application only: `mix compile`
Compile and perform static analysis (check for type-errors): `mix dialyzer`
Compile and execute test suite: `mix test`
Compile, execute test suite, and generate test coverage html: `MIX_ENV=test mix coveralls.html`
Compile and run application locally: `mix run`
Compile and run inside interactive elixir session: `iex -S mix`
Compile and start interactive elixir session inside application scope, without actually starting the application: `iex -S mix run --no-start`

# Debugging

```
$ iex -S mix run --no-start
# start the OTP observer:
iex(.)> :observer.start()
# start the GUI debugger:
iex(.)> :debugger.start()
# add modules to debugger (repeat for all modules you want to debug):
iex(.)> :int.ni(SomeModuleYouWantToDebug)
# start the application (the arguments are currently unused, so they don't matter):
iex(.)> CodaValidation.start([], [])
```

# TODO

- Fix auth token TTL expiration (refresh on interval?)
- Design spot providers and unify with log providers
- Implement aggregate statistics (as opposed to scalar statistics)
- Implement statistics subscribing to statistics (switch to defining list of data sources; check for cycles)
- Implement planning (given resources and validation requests, plan all process requests)
  - May involve dynamic request graph?
- Implement discord alerting backend
- Implement statistic exports (Prometheus interface; exported statistics selected by validation queries)
- Implement core statistics
  - Approximate frontier
    - Block acceptance rate
      - Aggregate block acceptance rate
    - Common prefix
    - Aggregate frontier?
- Abstract over cloud provider
- Dynamic resource classification
