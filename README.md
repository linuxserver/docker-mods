# Multi Language OCR - Docker mod for papermerge and paperless-ng/x

This mod adds multi language OCR packages to papermerge and paperless-ng/x, to be installed/updated during container start. Keep in mind that you still have to enable the languages in the app itself, as this mod only installs the system language packs.

In papermerge/paperless-ng/x docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:papermerge-multilangocr` to enable this mod.

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:papermerge-multilangocr|linuxserver/mods:papermerge-mod2`

Then set an environment variable named `OCRLANG` and set it to the language codes that follow `tesseract-ocr-` from [this page](https://packages.ubuntu.com/focal/tesseract-ocr-all). You can add multiple codes that are comma separated, with no spaces.

For example, if you want to enable OCR for Chinese Simple and Belarusian, you'd set the var as `-e OCRLANG="chi-sim,bel"`.
