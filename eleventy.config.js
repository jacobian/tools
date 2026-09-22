module.exports = function (eleventyConfig) {
  // Copy each tool's own CSS and JS through to the build.
  //
  // Listed per directory rather than as "**/*.js": that glob also swept up
  // build-time code -- _data/canyonlog.js and lib/ run during the build and
  // must not ship -- and Eleventy's passthrough copy supports no way to
  // exclude them (negated globs silently copy nothing).
  eleventyConfig.addPassthroughCopy("**/*.css");
  eleventyConfig.addPassthroughCopy("dsf-office-hours/*.js");
  eleventyConfig.addPassthroughCopy("trip-time-planner/*.js");
  // The canyon log lives in SQLite, which Eleventy has no reason to watch --
  // without this, editing the database leaves `just serve` showing stale data.
  eleventyConfig.addWatchTarget("data/canyons.db");

  eleventyConfig.setServerOptions({
    // liveReload doesn't seem to be working with Tailwind so turn it off.
    liveReload: false,
  });
};
