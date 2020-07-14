function req {
  curl "http://localhost:3087$1" -X POST -d "$2"
}
