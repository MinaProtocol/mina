#!/usr/bin/env node

var process = require('process');
var pandoc = require('pandoc-filter');
var Image = pandoc.Image;

const cdn = process.env['CODA_CDN_URL'];

function action(type,value,format,meta) {
  if (type === 'Image') {
    let url = value[2][0];
    if (url.startsWith('/')) {
      value[2][0] = cdn + url;
      return Image(value[0], value[1], value[2]);
    }
  }
  if (type === 'RawInline') {
    let haystack = value[1];
    value[1] = value[1].replace("/static/", cdn + "/static/")
  }
}

pandoc.stdio(action);

