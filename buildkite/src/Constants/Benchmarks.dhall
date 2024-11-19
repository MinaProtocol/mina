let Spec =
      { Type = { tokenEnvName : Text, bucket : Text, org : Text, host : Text }
      , default =
          { tokenEnvName = "\\\${INFLUXDB_TOKEN}"
          , bucket = "\\\${INFLUXDB_BUCKET_NAME}"
          , org = "\\\${INFLUXDB_ORG}"
          , host = "\\\${INFLUXDB_HOST}"
          }
      }

let toEnvList =
          \(spec : Spec.Type)
      ->  [ "INFLUXDB_HOST=${spec.host}"
          , "INFLUXDB_TOKEN=${spec.tokenEnvName}"
          , "INFLUXDB_ORG=${spec.org}"
          , "INFLUXDB_BUCKET_NAME=${spec.bucket}"
          ]

let mainlineBranches = "[develop,compatible,master]"

in  { Type = Spec, toEnvList = toEnvList, mainlineBranches = mainlineBranches }
