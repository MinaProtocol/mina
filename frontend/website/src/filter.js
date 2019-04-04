#!/usr/bin/env node

var process = require('process');
var pandoc = require('pandoc-filter');
var Image = pandoc.Image;

function action(type,value,format,meta) {

  if (type === 'Image') {
    let url = value[2][0];
    if (url.startsWith('/')) {
      value[2][0] = 'https://cdn.codaprotocol.com/v1' + url;
      return Image(value[0], value[1], value[2]);
    }
  }
}

pandoc.stdio(action);

