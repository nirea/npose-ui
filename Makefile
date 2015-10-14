.PHONY: serve echo

# Choose appropriate 'md5' command whether on linux or osx.
ifeq ($(shell which md5),)
MD5CMD="md5sum | awk '{ print $$1 }'" # Linux
else
MD5CMD="md5" # OSX
endif

APPJS_HASH=$(shell babel src/util.es src/main.jsx | uglifyjs -c -m | $(MD5CMD) | head -c 12)
CSS_HASH=$(shell lessc --clean-css src/style.less | $(MD5CMD) | head -c 12)

JSFILE="build/app.$(APPJS_HASH).js"
CSSFILE="build/style.$(CSS_HASH).css"

echo:
	echo $(APPJS_HASH)

serve:
	python -m SimpleHTTPServer 9000

$(JSFILE): src/main.jsx src/util.es
	mkdir -p build
	babel src/util.es src/main.jsx | uglifyjs -c -m > $@

$(CSSFILE): src/style.less
	mkdir -p build
	lessc --clean-css $< $@

index.html: index.html.tmpl $(JSFILE) $(CSSFILE)
	sed -e "s;%STYLESHEET%;$(CSSFILE);g" -e "s;%APPJS%;$(JSFILE);g" index.html.tmpl > $@
