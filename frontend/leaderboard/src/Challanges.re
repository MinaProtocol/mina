let calculateBlocksCreated = blocks => {
  Js.log("calculateBlocksCreated");
  Js.log(blocks);
  Array.map((block: Types.NewBlock.t) => {Js.log(block.data)}, blocks);
};

let calculateTransactionSent = blocks => {
  Js.log("calculateTransactionSent");
  Array.map((block: Types.NewBlock.t) => {Js.log(block.data)}, blocks);
};

let calculateSnarkWorkCreated = blocks => {
  Js.log("calculateSnarkWorkCreated");
  Array.map((block: Types.NewBlock.t) => {Js.log(block.data)}, blocks);
};

let handleMetrics = (metrics, blocks) => {
  Types.Metrics.(
    Array.map(
      metric => {
        switch (metric) {
        | BlocksCreated => blocks |> calculateBlocksCreated
        | TransactionsSent => blocks |> calculateTransactionSent
        | SnarkWorkCreated => blocks |> calculateSnarkWorkCreated
        }
      },
      metrics,
    )
  );
};