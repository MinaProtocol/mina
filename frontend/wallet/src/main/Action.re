// Actions for the application

type t('window) =
  | WalletInfo(array({. "publicKey": string}))
  | PutWindow(option('window))
  // stop by sending None
  // start by sending Some(args)
  // calltable pending resolves when graphql is ready
  // or immediately if we're turning it off
  | ControlCoda(option(list(string)), Messages.CallTable.Ident.Encode.t)
  // graphql is ready for the process started with these args
  | CodaGraphQLReady(list(string));
