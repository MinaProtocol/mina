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

let getBlocksCreatedByUser = blocks => {
  blocks
  |> Array.fold_left(
       (map, block: Types.NewBlock.t) => {
         updateMapValue(block.data.newBlock.creatorAccount.publicKey, map)
       },
       StringMap.empty,
     );
};

let calculateTransactionSent = (map, block: Types.NewBlock.t) => {
  block.data.newBlock.transactions.userCommands
  |> Array.fold_left(
       (transactionMap, userCommand: Types.NewBlock.userCommands) => {
         updateMapValue(userCommand.fromAccount.publicKey, transactionMap)
       },
       map,
     );
};

let getTransactionSentByUser = blocks => {
  blocks |> calculateProperty(calculateTransactionSent);
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

let getSnarkWorkCreatedByUser = blocks => {
  blocks |> calculateProperty(calculateSnarkWorkCount);
};

let mapMetricsToUser = (metricsMap, metrics) => {
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
       (metricsMap, metrics) => {mapMetricsToUser(metricsMap, metrics)},
       StringMap.empty,
     );
};

let delegateMetricsByType = (metric, blocks) => {
  Types.Metrics.(
    switch (metric) {
    | BlocksCreated =>
      blocks |> getBlocksCreatedByUser |> encodeMetric(Some(BlocksCreated))
    | TransactionsSent =>
      blocks
      |> getTransactionSentByUser
      |> encodeMetric(Some(TransactionsSent))
    | SnarkWorkCreated =>
      blocks
      |> getSnarkWorkCreatedByUser
      |> encodeMetric(Some(SnarkWorkCreated))
    }
  );
};

let processMetrics = (blocks, metrics) => {
  metrics |> Array.map(metric => {delegateMetricsByType(metric, blocks)});
};

let handleMetrics = (metrics, blocks) => {
  metrics |> processMetrics(blocks) |> mergeMetrics;
};