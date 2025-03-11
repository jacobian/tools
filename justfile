serve:
    rm -rf _site/  # workaround for https://github.com/11ty/eleventy/issues/1134
    npx @11ty/eleventy --serve