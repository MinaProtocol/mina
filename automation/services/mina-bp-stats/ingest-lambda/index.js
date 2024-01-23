const {Storage} = require('@google-cloud/storage');

exports.handleRequest = async (req, res) => {
  if (process.env.TOKEN === undefined){
    return res.status(500).send("TOKEN envar not set")
  }
  if (process.env.GOOGLE_STORAGE_BUCKET === undefined){
   return res.status(500).send("GOOGLE_STORAGE_BUCKET envar not set") 
  }

  if (!req.query.token || req.query.token !== process.env.TOKEN){
    return res.status(401).send("Bad token")
  }

  const now = new Date()  
  const dateStamp = now.toISOString().split('T')[0]

  const ipAddress = req.headers['x-forwarded-for'] || req.connection.remoteAddress
  const receivedAt = now.getTime()

  const recvPayload = req.body

  const bpKeys = recvPayload.daemonStatus.blockProductionKeys

  if (bpKeys.length === 0){
    return res.status(400).send("Invalid block production keys")
  }

  const payload = {
    receivedAt,
    receivedFrom: ipAddress,
    blockProducerKey: bpKeys[0],
    nodeData: recvPayload
  }

  // Upload to gstorage
  const storage = new Storage()
  const myBucket = storage.bucket(process.env.GOOGLE_STORAGE_BUCKET)
  const file = myBucket.file(`${dateStamp}.${now.getTime()}.${recvPayload.blockHeight}.json`)
  const contents = JSON.stringify(payload, null, 2)
  await file.save(contents, {contentType: "application/json"})
  
  return res.status(200).send("OK")
};
