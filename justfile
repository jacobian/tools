fetch-data:
    bin/fetch-canyons

serve: fetch-data
    rm -rf _site/  # workaround for https://github.com/11ty/eleventy/issues/1134
    npx @11ty/eleventy --serve

build: fetch-data
    npx @11ty/eleventy
