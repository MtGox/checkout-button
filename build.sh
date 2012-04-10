#!/bin/sh

# cleaning
if [ "$1" = "clean" ]; then
	echo -n "Cleaning ... ";
	rm -Rf docs/* dist/css/* dist/js/*;
	echo "done";
	exit 0;
fi;

TMP="/tmp/docs.$$"
if [ "$1" = "pages" ]; then
	cp -r docs "$TMP";
	git checkout gh-pages;
	rsync -avc "$TMP/" ./;
fi;

# check for pygments
if [ -z "$( which pygmentize 2>/dev/null  )" ]; then
	echo "Docco depends on python's pygments, please install it and make sure that pygmentize is in the PATH";
	exit 1;
fi;

# check for NPM
if [ -z "$( which npm 2>/dev/null  )" ]; then
        echo "Please install node.js and make sure that npm is in the PATH";
        exit 1;
fi;

# install dependencies
echo -n "Installing/Updating dependencies ... "
TMP=`npm install 2>&1`
if [ $? != 0 ]; then echo "failed"; echo "$TMP"; exit 1; fi
TMP=`npm update 2>&1`
if [ $? != 0 ]; then echo "failed"; echo "$TMP"; exit 1; fi
echo "done"

# build the doc
echo "Building documentation ..."
node_modules/.bin/styledocco -n "MtGox" src/less/mtgox.less README.md
node_modules/.bin/docco src/coffee/mtgox.coffee

# build the dist files
# CSS
echo -n "Building CSS ... "
node_modules/.bin/lessc src/less/mtgox.less dist/css/mtgox.css
echo -n "minimizing ... "
node_modules/.bin/lessc src/less/mtgox.less --yui-compress dist/css/mtgox.min.css
echo "done"
# JS
echo -n "Building JS ... "
node_modules/.bin/coffee -o dist/js/ -c src/coffee/mtgox.coffee
echo -n "minimizing ... "
node_modules/.bin/uglifyjs dist/js/mtgox.js > dist/js/mtgox.min.js
echo "done"
