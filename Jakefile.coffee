# new build file using jake
spawn = require('child_process').spawn;
fs = require 'fs'

node_exec = (cmd, args, cb) ->
	stderr = ''
	stdout = ''
	ps = spawn 'node_modules/.bin/' + cmd, args
	ps.stderr.on 'data', (data) ->
		stderr += data
	ps.stdout.on 'data', (data) ->
		stdout += data
	ps.on 'exit', (code) ->
		cb(code, stdout, stderr)

# dependencie management
namespace 'dependencies', ->
	desc 'Check for Pygments'
	task 'pygments', [], ->
		# just try to spawn pygmentize
		spawn('pygmentize', ['-V']).on 'exit', (code) ->
			fail 'Please install pygments and make sure that pygmentize is in the path' if code != 0
			console.log 'pygmentize ... found'

# build distribution files
namespace 'dist', ->
	desc 'Build the CSS'
	task 'css', [], ->
		node_exec 'lessc', ['src/less/mtgox.less', 'dist/css/mtgox.css'], (code, stdout, stderr) ->
			if code != 0
				console.log 'lessc exited with code ' + code
				console.log stderr
				fail 'Failed compiling CSS'
			else
				console.log 'Compiled src/less/mtgox.less as dist/css/mtgox.css'
				jake.Task['dist:css-minified'].invoke()

	# called once the CSS is generated
	desc 'Build the minified CSS'
	task 'css-minified', [], ->
		node_exec 'lessc', ['src/less/mtgox.less', '--yui-compress', 'dist/css/mtgox.min.css'], (code, stdout, stderr) ->
			if code != 0
				console.log 'lessc exited with code ' + code
				console.log stderr
				fail 'Failed compiling minified CSS'
			else
				console.log 'Minified src/less/mtgox.less as dist/css/mtgox.min.css'

	# javascript
	desc 'Build the Javascript'
	task 'js', [], ->
		#console.log @description
		node_exec 'coffee', ['-o', 'dist/js/', '-c', 'src/coffee/mtgox.coffee'], (code, stdout, stderr) ->
			if code != 0
				console.log 'coffee exited with code ' + code
				console.log stderr
				fail 'Failed compiling CoffeeScript'
			else
				console.log 'Compiled src/coffee/mtgox.coffee as dist/js/mtgox.js'
				jake.Task['dist:js-minified'].invoke()

	# minify generated javascript
	desc 'Build the minified Javascript'
	task 'js-minified', [], ->
		#console.log @description
		node_exec 'uglifyjs', ['dist/js/mtgox.js'], (code, stdout, stderr) ->
			if code != 0
				console.log 'uglifyjs exited with code ' + code
				console.log stderr
				fail 'Failed minifying Javascript'
			else
				fs.writeFile 'dist/js/mtgox.min.js', stdout, ->
					console.log 'File dist/js/mtgox.js minified as dist/js/mtgox.min.js'

# build the documentation
namespace 'doc', ->
	desc 'Build LESS documentation'
	task 'less', ['dependencies:pygments'], ->
		node_exec 'styledocco', ['-n', 'MtGox', 'src/less/mtgox.less'], (code, stdout, stderr) ->
			if code != 0
				console.log 'styledocco exited with code ' + code
				console.log stderr
				fail 'Failed building style documentation'
			else
				console.log 'Compiled documentation for src/less/mtgox.less'

	desc 'Build script documentation'
	task 'coffee', ['dependencies:pygments'], ->
		node_exec 'docco', ['src/coffee/mtgox.coffee'], (code, stdout, stderr) ->
			if code != 0
				console.log 'docco exited with code ' + code
				console.log stderr
				fail 'Failed building script documentation'
			else
				console.log 'Compiled documentation for src/coffee/mtgox.coffee'

desc 'Build the distribution files'
task 'dist', ['dist:css', 'dist:js'], ->
	# let the dependencies do the work

desc 'Build the documentation'
task 'doc', ['doc:less', 'doc:coffee'], ->
	# let the dependencies do the work

desc 'Build the project and documentation'
task 'default', ['dist', 'doc'], ->
	# let the dependencies do the work

