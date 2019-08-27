[@bs.deriving abstract]
type subscriptionClientOptions = {
  [@bs.optional]
  timeout: int,
  [@bs.optional] [@bs.as "lazy"]
  lazy_: bool,
  [@bs.optional]
  reconnect: bool,
  [@bs.optional]
  reconnectionAttempts: int,
  [@bs.optional]
  connectionCallback: Js.Exn.t => unit,
  [@bs.optional]
  inactivityTimer: int,
};

type websocketImpl;

[@bs.deriving abstract]
type subscriptionClientConfig = {
  [@bs.optional]
  options: subscriptionClientOptions,
};

type executionResult;

type client = {
  .
  [@bs.meth]
  "request":
    UrqlClient.UrqlExchanges.subscriptionOperation =>
    UrqlClient.UrqlExchanges.observableLike(UrqlClient.Types.executionResult),
};

[@bs.new] [@bs.module "subscriptions-transport-ws"]
external subscriptionClient:
  (
    ~url: string,
    ~subscriptionClientConfig: subscriptionClientConfig=?,
    ~websocketImpl: websocketImpl=?
  ) =>
  client =
  "SubscriptionClient";
