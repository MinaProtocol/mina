const { STATUS_CODES } = require('http');

class HTTPError extends Error {
  constructor(code, message = STATUS_CODES[code]) {
    super(message);
    this.name = code.toString();
    this.statusCode = code;
  }
}

module.exports = HTTPError;
