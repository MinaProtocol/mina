type t;
[@bs.new] external create: string => t = "Worker";

module Promise = {
  type promiseWorker;

  [@bs.module "promise-worker"] [@bs.new]
  external create: t => promiseWorker = "PromiseWorker";

  // danger: untyped
  [@bs.send]
  external postMessage: (promiseWorker, 'a) => Js.Promise.t('b) =
    "postMessage";

  type t = promiseWorker;
};
