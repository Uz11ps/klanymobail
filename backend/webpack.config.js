/**
 * Nest CLI merges this into its default webpack config.
 * Webpack often stays silent for minutes on slow VPS — ProgressPlugin proves the step is alive.
 */
const webpack = require('webpack');

module.exports = function (options) {
  let lastPrintedBucket = -1;

  return {
    ...options,
    plugins: [
      ...(options.plugins || []),
      new webpack.ProgressPlugin({
        handler(percentage, message, ...args) {
          const pct = Math.floor(percentage * 100);
          const tail =
            args.length > 0 ? ` ${args.map((a) => String(a)).join(' ')}` : '';

          if (percentage >= 1) {
            console.info(`[nest/webpack] 100% ${message}${tail}`);
            return;
          }

          const bucket = Math.floor(pct / 10) * 10;
          if (bucket === lastPrintedBucket) return;
          lastPrintedBucket = bucket;
          console.info(`[nest/webpack] ${pct}% ${message}${tail}`);
        },
      }),
    ],
  };
};
