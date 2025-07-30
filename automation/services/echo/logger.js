const { createLogger, format, transports } = require("winston");

let logger = createLogger({
  level: "info",
  format: format.combine(
    format.timestamp({
      format: "YYYY-MM-DD HH:mm:ss"
    }),
    format.errors({ stack: true }),
    format.splat(),
    format.json()
  ),
  defaultMetadata: { service: "echo-service" },
  transports: [
    new transports.File({
      filename: "logs/echo-service-error.log",
      level: "error"
    }),
    new transports.File({ filename: "logs/echo-service-combined.log" }),
    new transports.Console({
      format: format.combine(format.colorize(), format.simple())
    })
  ]
});

module.exports = logger;
