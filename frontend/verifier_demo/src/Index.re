let worker = Worker.create("./worker.js");
let promiseWorker = Worker.Promise.create(worker);

[@bs.val] [@bs.scope "location"] external reload: unit => unit = "reload";
let _ = Js.Global.setTimeout(reload, 5 * 60 * 1000);

ReactDOMRe.renderToElementWithId(<Demo worker=promiseWorker />, "demo");
