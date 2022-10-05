# Mina Block Producer Ingest Lambda

This is a simple ingestion lambda that tags incoming stats data and lands things in a GCS bucket. 

## Configuration

This lambda takes in 2 environment variables that should be configured in the google console.

- `TOKEN` - The token used to authenticate incoming requests
- `GOOGLE_STORAGE_BUCKET` - The GCS bucket to store incoming data in
