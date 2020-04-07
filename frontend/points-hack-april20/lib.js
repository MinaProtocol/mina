const {Storage} = require('@google-cloud/storage');
const { Readable } = require('stream');

const storage = new Storage();

function uploadFile() {
  const bucketName = "points-data-hack-april20";
  const filename = "metric" + Date.now();

  const bucket = storage.bucket(bucketName);
  const file = bucket.file("test/" + filename);

  const buffer = Buffer.from(JSON.stringify({x: 3, y: "hello"}), 'utf8');
  const readable = new Readable();
  readable._read = () => {};
  readable.push(buffer);
  readable.push(null);

  readable.pipe(file.createWriteStream({
    metadata: {
      contentType: 'application/json',
      metadata: {
        cacheControl: 'public, max-age=31536000',
      }
    }
  }))
  .on('error', function(err) {
      console.error(err);
  })
  .on('finish', function() {
      console.log(`Finished uploading ${filename} to ${bucketName}`);
  });
}

uploadFile()

