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

let calculateBlocksCreated = blocks => {
  Array.fold_left(
    (map, block: Types.NewBlock.t) => {
      StringMap.update(
        block.data.newBlock.creatorAccount.publicKey,
        value =>
          switch (value) {
          | Some(blockCount) => Some(blockCount + 1)
          | None => Some(1)
          },
        map,
      )
    },
    StringMap.empty,
    blocks,
  );
};

let calculateTransactionSent = blocks => {
  Array.fold_left(
    (map, block: Types.NewBlock.t) => {
      Array.fold_left(
        (map, userCommand: Types.NewBlock.userCommands) => {
          StringMap.update(
            userCommand.fromAccount.publicKey,
            value =>
              switch (value) {
              | Some(transaction) => Some(transaction + 1)
              | None => Some(1)
              },
            map,
          )
        },
        map,
        block.data.newBlock.transactions.userCommands,
      )
    },
    StringMap.empty,
    blocks,
  );
};

let calculateSnarkWorkCreated = blocks => {
  Array.fold_left(
    (map, block: Types.NewBlock.t) => {
      Array.fold_left(
        (map, snarkJob: Types.NewBlock.snarkJobs) => {
          StringMap.update(
            snarkJob.prover,
            value =>
              switch (value) {
              | Some(snarkWork) => Some(snarkWork + 1)
              | None => Some(1)
              },
            map,
          )
        },
        map,
        block.data.newBlock.snarkJobs,
      )
    },
    StringMap.empty,
    blocks,
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
  Array.fold_left(
    (map, result) => {
      let (metricName, metricData) = result;

      StringMap.fold(
        (publicKey, metricCount, map) => {
          StringMap.update(
            publicKey,
            value =>
              switch (value) {
              | Some(currentMetrics) =>
                Some(
                  Array.append(
                    [|(metricName, metricCount)|],
                    currentMetrics,
                  ),
                )
              | None => Some([|(metricName, metricCount)|])
              },
            map,
          )
        },
        metricData,
        map,
      );
    },
    StringMap.empty,
    metricsList,
  );
};

let handleMetrics = (metrics, blocks) => {
  Types.Metrics.(
    Array.map(
      metric => {
        switch (metric) {
        | BlocksCreated =>
          blocks |> calculateBlocksCreated |> encodeMetric(BlocksCreated)
        | TransactionsSent =>
          blocks |> calculateTransactionSent |> encodeMetric(TransactionsSent)
        | SnarkWorkCreated =>
          blocks
          |> calculateSnarkWorkCreated
          |> encodeMetric(SnarkWorkCreated)

        | _ => ("", StringMap.empty)
        }
      },
      metrics,
    )
    |> mergeMetrics
  );
};