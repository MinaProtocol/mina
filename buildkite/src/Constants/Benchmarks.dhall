let Spec =
      { Type = { tokenEnvName : Text, bucket : Text, org : Text, host : Text }
      , default =
          { tokenEnvName =
              "hxEc4COeR59kJXDyQp9g1TB_kKqxDspyBKdl0omdNY615j_2Opf-URZO2NeA3gy4dotlJ8vBrdds_ribgl58dw=="
          , bucket = "mina-benchmarks"
          , org = "Dev"
          , host = "https://eu-central-1-1.aws.cloud2.influxdata.com/"
          }
      }

let toEnvList =
          \(spec : Spec.Type)
      ->  [ "INFLUX_HOST=${spec.host}"
          , "INFLUX_TOKEN=${spec.tokenEnvName}"
          , "INFLUX_ORG=${spec.org}"
          , "INFLUX_BUCKET_NAME=${spec.bucket}"
          ]

let mainlineBranches = "[develop,compatible,master]"

in  { Type = Spec, toEnvList = toEnvList, mainlineBranches = mainlineBranches }
