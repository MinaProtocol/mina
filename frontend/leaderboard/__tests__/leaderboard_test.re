open Jest;
open Expect;
module StringMap = Map.Make(String);

let blockChallenge = "Stake your Coda and produce blocks";

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
    test("correct number of users exist in the metrics map", () => {
      expect(StringMap.cardinal(blockMetrics)) |> toBe(4)
    });
    test("correct number of blocks for publickey1", () => {
      expect(StringMap.find("publickey1", blockMetrics)) |> toBe(4)
    });
    test("correct number of blocks for publickey2", () => {
      expect(StringMap.find("publickey2", blockMetrics)) |> toBe(3)
    });
    test("correct number of blocks for publickey3", () => {
      expect(StringMap.find("publickey3", blockMetrics)) |> toBe(2)
    });
    test("correct number of blocks for publickey4", () => {
      expect(StringMap.find("publickey4", blockMetrics)) |> toBe(1)
    });
    test("publickey5 does not exist in metrics map", () => {
      expect(() =>
        StringMap.find("publickey5", blockMetrics)
      )
      |> toThrowException(Not_found)
    });
  })
});

describe("Points functions", () => {
  let blockMetrics = blocks |> Metrics.calculateMetrics;

  describe("addPointsToAtleastN", () => {
    describe("adds correct number of points with atleast 1", () => {
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
      test("publickey8 does not exist in points map", () => {
        expect(() =>
          StringMap.find("publickey8", blockPoints)
        )
        |> toThrowException(Not_found)
      });
    });

    describe("adds correct number of points with atleast 3", () => {
      let blockPoints =
        Challenges.addPointsToUsersWithAtleastN(
          (metricRecord: Types.Metrics.metricRecord) =>
            metricRecord.blocksCreated,
          3,
          1000,
          blockMetrics,
        );

      test("correct number of points given to publickey1", () => {
        expect(StringMap.find("publickey1", blockPoints)) |> toBe(1000)
      });

      test("correct number of points given to publickey2", () => {
        expect(StringMap.find("publickey2", blockPoints)) |> toBe(1000)
      });

      test("publickey3 does not exist in points map", () => {
        expect(() =>
          StringMap.find("publickey3", blockPoints)
        )
        |> toThrowException(Not_found)
      });
    });
    describe("applyTopNPoints", () => {
      describe("adds correct number of points to top 3", () => {
        let blockPoints =
          Challenges.applyTopNPoints(
            3, 1000, blockMetrics, (metricRecord: Types.Metrics.metricRecord) =>
            metricRecord.blocksCreated
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

        test("publickey4 does not exist in points map", () => {
          expect(() =>
            StringMap.find("publickey4", blockPoints)
          )
          |> toThrowException(Not_found)
        });
      })
    });
    describe("applyNPlacePoints", () => {
      describe("adds correct number of points to the user in 1st place", () => {
        let blockPoints =
          Challenges.applyNPlacePoints(
            0, 1000, blockMetrics, (metricRecord: Types.Metrics.metricRecord) =>
            metricRecord.blocksCreated
          );
        test("only 1 user is given points for 1st Place", () => {
          expect(StringMap.cardinal(blockPoints)) |> toBe(1)
        });
        test("correct number of points given to publickey1", () => {
          expect(StringMap.find("publickey1", blockPoints)) |> toBe(1000)
        });
      })
    });
    describe("applyPointsToRange", () => {
      describe("adds correct number of points to user in the top 3", () => {
        let blockPoints =
          Challenges.applyPointsToRange(
            0,
            3,
            1000,
            blockMetrics,
            (metricRecord: Types.Metrics.metricRecord) =>
            metricRecord.blocksCreated
          );

        test("only 3 users should exist in the points map", () => {
          expect(StringMap.cardinal(blockPoints)) |> toBe(3)
        });
        test("correct number of points given to publickey1", () => {
          expect(StringMap.find("publickey1", blockPoints)) |> toBe(1000)
        });
        test("correct number of points given to publickey2", () => {
          expect(StringMap.find("publickey2", blockPoints)) |> toBe(1000)
        });
        test("correct number of points given to publickey3", () => {
          expect(StringMap.find("publickey3", blockPoints)) |> toBe(1000)
        });
        test("publickey4 does not exist in points map", () => {
          expect(() =>
            StringMap.find("publickey4", blockPoints)
          )
          |> toThrowException(Not_found)
        });
      });
      describe(
        "adds correct number of points to top 1 and top 3-4 placed users", () => {
        let blockPoints =
          [
            Challenges.applyPointsToRange(
              0,
              1,
              1000,
              blockMetrics,
              (metricRecord: Types.Metrics.metricRecord) =>
              metricRecord.blocksCreated
            ),
            Challenges.applyPointsToRange(
              2,
              4,
              1000,
              blockMetrics,
              (metricRecord: Types.Metrics.metricRecord) =>
              metricRecord.blocksCreated
            ),
          ]
          |> Challenges.sumPointsMaps;

        test("correct number of users exist in the points map", () => {
          expect(StringMap.cardinal(blockPoints)) |> toBe(3)
        });
        test("correct number of points given to publickey1", () => {
          expect(StringMap.find("publickey1", blockPoints)) |> toBe(1000)
        });
        test("correct number of points given to publickey3", () => {
          expect(StringMap.find("publickey3", blockPoints)) |> toBe(1000)
        });
        test("correct number of points given to publickey4", () => {
          expect(StringMap.find("publickey4", blockPoints)) |> toBe(1000)
        });
      });
    });
  });
});