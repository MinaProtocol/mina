open Jest;
open Expect;
module StringMap = Map.Make(String);

let blockDirectory =
  ([%bs.node __dirname] |> Belt.Option.getExn |> Filename.dirname)
  ++ "/../../__tests__/blocks/";

let blocks =
  blockDirectory
  |> Node.Fs.readdirSync
  |> Array.map(file => {
       let fileContents = Node.Fs.readFileAsUtf8Sync(blockDirectory ++ file);
       let blockData = Js.Json.parseExn(fileContents);
       let block = Types.NewBlock.unsafeJSONToNewBlock(blockData);
       block.data.newBlock;
     });

describe("Metrics", () => {
  describe("blocksCreatedMetric", () => {
    let blockMetrics = Metrics.getBlocksCreatedByUser(blocks);
    test("correct number of users", () => {
      expect(StringMap.cardinal(blockMetrics)) |> toBe(7)
    });
    test("correct number of blocks for publickey1", () => {
      expect(StringMap.find("publickey1", blockMetrics)) |> toBe(3)
    });
    test("correct number of blocks for publickey2", () => {
      expect(StringMap.find("publickey2", blockMetrics)) |> toBe(2)
    });
    test("correct number of blocks for publickey3", () => {
      expect(StringMap.find("publickey3", blockMetrics)) |> toBe(1)
    });
  })
});

describe("Challenges", () => {
  describe("Blocks Challenge", () => {
    let blocksPoints =
      blocks
      |> Metrics.calculateMetrics
      |> Challenges.calculatePoints("Blocks")
      |> Belt.Option.getExn;

    test("1000 points given to publickey1", () => {
      expect(StringMap.find("publickey1", blocksPoints)) |> toBe(1000)
    });
  });

  describe("Points functions", () => {
    let blockMetrics = blocks |> Metrics.calculateMetrics;
    describe(
      "addPointsToAtleastN adds correct number of points with atleast 1", () => {
      let blockPoints =
        Challenges.addPointsToUsersWithAtleastN(
          (metricRecord: Types.Metrics.metricRecord) =>
            metricRecord.blocksCreated,
          1,
          1000,
          blockMetrics,
        );

      test("correct number of points given to publickey1", () => {
        expect(StringMap.find("publickey1", blockPoints)) |> toBe(1000)
      });
      test("correct number of points given to publickey2", () => {
        expect(StringMap.find("publickey2", blockPoints)) |> toBe(1000)
      });
      test("correct number of points given to publickey3", () => {
        expect(StringMap.find("publickey3", blockPoints)) |> toBe(1000)
      });
      test("no points exist for publickey8", () => {
        expect(() =>
          StringMap.find("publickey8", blockPoints)
        )
        |> toThrowException(Not_found)
      });
    });
  });
});