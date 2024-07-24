#!/bin/bash
set -eo pipefail

# Function to create cache directory with subdirectories for pallas and vesta
create_cache_dir() {
  local cache_dir=$1
  mkdir -p "$cache_dir/pallas" "$cache_dir/vesta"
}

# Function to restore cache, preserving the directory structure
restore_cache() {
  local bucket_name=$1
  local cache_dir=$2

  echo "Restoring cache from bucket: gs://$bucket_name"
  
  if gcloud storage cp -r "gs://$bucket_name/pallas/*" "$cache_dir/pallas/" && \
     gcloud storage cp -r "gs://$bucket_name/vesta/*" "$cache_dir/vesta/"; then
    echo "Cache restored from GCS."
  else
    echo "No cache found. Starting with a fresh cache."
  fi
}

# Function to list files in GCS bucket with error handling for empty directories
list_gcs_files() {
  local bucket_name=$1
  local prefix=$2
  gcloud storage ls -r "gs://$bucket_name/$prefix/**" 2>/dev/null | sed 's#gs://'$bucket_name'/##' || true
}

# Function to upload only new or changed files, preserving the directory structure
upload_cache_if_changed() {
  local bucket_name=$1
  local cache_dir=$2

  # List files currently in the bucket, restricted to pallas and vesta directories
  bucket_files=$(list_gcs_files "$bucket_name" "pallas")
  bucket_files+=$'\n'
  bucket_files+=$(list_gcs_files "$bucket_name" "vesta")

  # Create a list of files currently in the cache directory, restricted to pallas and vesta directories
  local_files=$(find "$cache_dir/pallas" "$cache_dir/vesta" -type f | sed 's#^'$cache_dir'/##')

  # Find new or changed files by comparing the lists
  while IFS= read -r file; do
    if ! echo "$bucket_files" | grep -qxF "$file"; then
      local_path="$cache_dir/$file"
      if ! gcloud storage cp "$local_path" "gs://$bucket_name/$file"; then
        echo "Failed to upload $local_path to GCS." >&2
        return 0
      fi
    fi
  done <<< "$local_files"

  echo "New or changed files uploaded to GCS."
  return 0
}

# Function to display usage
usage() {
  echo "Usage: $0 {create_cache_dir|restore_cache|upload_cache_if_changed} args"
  echo "Commands:"
  echo "  create_cache_dir cache_dir"
  echo "  restore_cache bucket_name cache_dir"
  echo "  upload_cache_if_changed bucket_name cache_dir"
  exit 1
}

# Main function to handle different operations
main() {
  if [ $# -lt 1 ]; then
    usage
  fi

  local command=$1
  shift

  case "$command" in
    create_cache_dir)
      create_cache_dir "$@"
      ;;
    restore_cache)
      restore_cache "$@"
      ;;
    upload_cache_if_changed)
      upload_cache_if_changed "$@"
      ;;
    *)
      usage
      ;;
  esac
}

# Execute main function
main "$@"