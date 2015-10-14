.PHONY: serve s3 clean

BUCKET=ui.npose.org

# Choose appropriate 'md5' command whether on linux or osx.
ifeq ($(shell which md5),)
MD5CMD="md5sum | awk '{ print $$1 }'" # Linux
else
MD5CMD="md5" # OSX
endif

UPSTREAM_JS=node_modules/babel-core/browser-polyfill.min.js node_modules/babel-core/browser.min.js node_modules/react/dist/react-with-addons.js node_modules/react-dom/dist/react-dom.min.js vendor/jsonp.js

APPJS_HASH=$(shell babel src/util.es src/main.jsx | uglifyjs -c -m | $(MD5CMD) | head -c 12)
CSS_HASH=$(shell lessc --clean-css src/style.less | $(MD5CMD) | head -c 12)

JSFILE="build/app.$(APPJS_HASH).js"
CSSFILE="build/style.$(CSS_HASH).css"

serve:
	python -m SimpleHTTPServer 9000

$(JSFILE): src/main.jsx src/util.es
	mkdir -p build
	babel src/util.es src/main.jsx | uglifyjs -c -m > $@


$(CSSFILE): src/style.less
	mkdir -p build
	lessc --clean-css $< $@

index.html: index.html.tmpl $(JSFILE) $(CSSFILE)
	sed -e "s;%STYLESHEET%;$(CSSFILE);g" -e "s;%UPSTREAMJS%;$(UPSTREAM_JSFILE);g" -e "s;%APPJS%;$(JSFILE);g" index.html.tmpl > $@
	cp $(UPSTREAM_JS) build/

clean:
	-rm -rf build/*

$(UPSTREAM_JS):
	npm install

s3: clean index.html error.html $(UPSTREAM_JS)
	aws s3 rm s3://$(BUCKET)/ --recursive
	aws s3 cp index.html s3://$(BUCKET)/index.html --grants read=uri=http://acs.amazonaws.com/groups/global/AllUsers
	aws s3 cp error.html s3://$(BUCKET)/error.html --grants read=uri=http://acs.amazonaws.com/groups/global/AllUsers
	aws s3 sync build s3://$(BUCKET)/build --grants read=uri=http://acs.amazonaws.com/groups/global/AllUsers
	aws s3 sync img s3://$(BUCKET)/img --grants read=uri=http://acs.amazonaws.com/groups/global/AllUsers
