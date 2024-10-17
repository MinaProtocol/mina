let Spec =
      { Type = { tokenEnvName : Text, bucket : Text, org : Text, host : Text }
      , default =
          { tokenEnvName = "\\\${INFLUX_TOKEN}"
          , bucket = "\\\${INFLUX_BUCKET_NAME}"
          , org = "\\\${INFLUX_ORG}"
          , host = "\\\${INFLUX_HOST}"
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
