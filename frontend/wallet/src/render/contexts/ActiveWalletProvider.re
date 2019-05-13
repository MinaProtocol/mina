module ActiveWalletContextType = {
  type t = (option(PublicKey.t), PublicKey.t => unit);

  let initialContext = (None, _ => ());
};

type t = ActiveWalletContextType.t;
include ContextProvider.Make(ActiveWalletContextType);
