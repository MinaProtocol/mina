module StringMap = Map.Make(String);

let printMap = map => {
  StringMap.mapi(
    (key, value) => {
      Js.log(key);
      Js.log(value);
    },
    map,
  );
};

let encodeMetric = (metricType, metric) => {
  (Types.Metrics.stringOfMetric(metricType), metric);
};

let calculateProperty = (f, blocks) => {
  blocks
  |> Array.fold_left((map, block) => {f(map, block)}, StringMap.empty);
};

let updateMapValue = (key, map) => {
  map
  |> StringMap.update(key, value => {
       switch (value) {
       | Some(valueCount) => Some(valueCount + 1)
       | None => Some(1)
       }
     });
};

let calculateBlocksCreated = blocks => {
  blocks
  |> Array.fold_left(
       (map, block: Types.NewBlock.t) => {
         updateMapValue(block.data.newBlock.creatorAccount.publicKey, map)
       },
       StringMap.empty,
     );
};

let calculateTransactionCount = (map, block: Types.NewBlock.t) => {
  block.data.newBlock.transactions.userCommands
  |> Array.fold_left(
       (transactionMap, userCommand: Types.NewBlock.userCommands) => {
         updateMapValue(userCommand.fromAccount.publicKey, transactionMap)
       },
       map,
     );
};

let calculateTransactionSent = blocks => {
  blocks |> calculateProperty(calculateTransactionCount);
};

let calculateSnarkWorkCount = (map, block: Types.NewBlock.t) => {
  block.data.newBlock.snarkJobs
  |> Array.fold_left(
       (snarkMap, snarkJob: Types.NewBlock.snarkJobs) => {
         updateMapValue(snarkJob.prover, snarkMap)
       },
       map,
     );
};

let calculateSnarkWorkCreated = blocks => {
  blocks |> calculateProperty(calculateSnarkWorkCount);
};

let combineMetrics = (metricsMap, metrics) => {
  let (metricName, metricData) = metrics;

  metricsMap
  |> StringMap.fold(
       (publicKey, metricCount, map) => {
         map
         |> StringMap.update(publicKey, value =>
              switch (value) {
              | Some(currentMetrics) =>
                Some(
                  Array.append(
                    [|(metricName, metricCount)|],
                    currentMetrics,
                  ),
                )
              | None => Some([|(metricName, metricCount)|])
              }
            )
       },
       metricData,
     );
};

/*
     Returns a map that contains a publicKey and an array of tuples representing it's data.
     The tuple is a pair of metric name and the metric value.

     The final output should be of the form:
       [
         publicKey1: [(blocks_created, 2), (transactions_sent, 5)]
         publicKey2: [(blocks_created, 1))]
         ...
       ]

 */
let mergeMetrics = metricsList => {
  metricsList
  |> Array.fold_left(
       (metricsMap, metrics) => {combineMetrics(metricsMap, metrics)},
       StringMap.empty,
     );
};

let delegateMetrics = (metric, blocks) => {
  Types.Metrics.(
    switch (metric) {
    | BlocksCreated =>
      blocks |> calculateBlocksCreated |> encodeMetric(Some(BlocksCreated))
    | TransactionsSent =>
      blocks
      |> calculateTransactionSent
      |> encodeMetric(Some(TransactionsSent))
    | SnarkWorkCreated =>
      blocks
      |> calculateSnarkWorkCreated
      |> encodeMetric(Some(SnarkWorkCreated))
    }
  );
};

let processMetrics = (blocks, metrics) => {
  metrics |> Array.map(metric => {delegateMetrics(metric, blocks)});
};

let handleMetrics = (metrics, blocks) => {
  metrics |> processMetrics(blocks) |> mergeMetrics |> printMap;
};