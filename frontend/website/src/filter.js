#!/usr/bin/env node

const process = require('process');
const pandoc = require('pandoc-filter');
const crypto = require('crypto');
const fs = require('fs');
var Image = pandoc.Image;

const cdn = process.env['CODA_CDN_URL'];

function rewriteUrl(cdnPrefix, url) {
  let localPath = url.replace("/static/", "static/");
  let content = fs.readFileSync(localPath, {encoding: "utf8"});
  let hashGen = crypto.createHash("sha256");
  hashGen.update(content);
  let hash = hashGen.digest("hex");

  let index = url.lastIndexOf(".");
  return cdnPrefix + url.substring(0, index) + "-" + hash + url.substring(index);
}

function action(type,value,format,meta) {
  if (type === 'Image') {
    let url = value[2][0];
    if (url.startsWith('/')) {
      value[2][0] = rewriteUrl(cdn, url);
      return Image(value[0], value[1], value[2]);
    }
  }
  if (type === 'RawInline') {
    let search = value[1].match(/(('|")\/static[^'"]*('|"))/);
    if (search != null) {
      let url = search [0].replace(/['"]/g, "");
      let rewritten = rewriteUrl(cdn, url);
      value[1] = value[1].replace(url, rewritten);
    }
  }
}

pandoc.stdio(action);

