# Coda Documentation

This folder contains all the source docs for the Coda Documentation site.

## Development

#### Install dependencies

Install MkDocs - `brew install mkdocs`

#### Using MkDocs

The Coda Documentation site uses MkDocs, which is a simple markdown based documentation generator. The top level `docs` folder contains `mkdocs.yaml` which contains all the configuration level details. The nested `docs` folder contains the documentation source files. 

To run the dev server and hot-reload changes, simply run `mkdocs serve`:

```
$ mkdocs serve
INFO    -  Building documentation...
INFO    -  Cleaning site directory
[I 190708 17:53:08 server:296] Serving on http://127.0.0.1:8000
[I 190708 17:53:08 handlers:62] Start watching changes
[I 190708 17:53:08 handlers:64] Start detecting changes
```

Visit `localhost:8000` in your browser to see the output of the dev server.

## Deploying

TODO