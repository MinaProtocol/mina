let worker = Worker.create("./worker.js");
let promiseWorker = Worker.Promise.create(worker);

ReactDOMRe.renderToElementWithId(<Demo worker=promiseWorker />, "demo");
