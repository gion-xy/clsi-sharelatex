Path = require "path"
Settings = require "settings-sharelatex"
logger = require "logger-sharelatex"
Metrics = require "./Metrics"
CommandRunner = require "./CommandRunner"

module.exports = LatexRunner =
	runLatex: (project_id, options, callback = (error, streams) ->) ->
		{mainFile, compiler} = options
		compiler ||= "pdflatex"
		
		limits = {
			timeout:    options.timeout or 60000 # milliseconds
			memory:     options.memory or 512 # Mb
			cpu_shares: options.cpu_shares or 1024 # Relative weighting, 1024 is default
			processes:  options.processes or 100 # Number of running processes
			imageName:  options.imageName
		}

		logger.log {project_id, compiler, limits, mainFile}, "starting compile"

		# We want to run latexmk on the tex file which we will automatically
		# generate from the Rtex file.
		mainFile = mainFile.replace(/\.Rtex$/, ".tex")
		privileged = false

		if compiler == "pdflatex"
			command = LatexRunner._pdflatexCommand mainFile
		else if compiler == "latex"
			command = LatexRunner._latexCommand mainFile
		else if compiler == "xelatex"
			command = LatexRunner._xelatexCommand mainFile
		else if compiler == "lualatex"
			command = LatexRunner._lualatexCommand mainFile
		else if compiler == "python"
			command = LatexRunner._pythonCommand mainFile
		else if compiler == "r"
			command = LatexRunner._rCommand mainFile
		else if compiler == "command"
			command = options.command
		else if compiler == "apt-get-install"
			command = LatexRunner._aptGetInstallCommand options.package
			privileged = true
		else if compiler == 'package-install'
			command = LatexRunner._packageInstallCommand options.package, options.source
			privileged = true
		else
			return callback new Error("unknown compiler: #{compiler}")

		CommandRunner.run project_id, command, { env: options.env, privileged }, limits, callback

	_latexmkBaseCommand: [ "latexmk", "-cd", "-f", "-jobname=output", "-auxdir=$COMPILE_DIR", "-outdir=$COMPILE_DIR"]

	_pdflatexCommand: (mainFile) ->
		LatexRunner._latexmkBaseCommand.concat [
			"-pdf", "-e", "$pdflatex='pdflatex -synctex=1 -interaction=batchmode %O %S'",
			Path.join("$COMPILE_DIR", mainFile)
		]
		
	_latexCommand: (mainFile) ->
		LatexRunner._latexmkBaseCommand.concat [
			"-pdfdvi", "-e", "$latex='latex -synctex=1 -interaction=batchmode %O %S'",
			Path.join("$COMPILE_DIR", mainFile)
		]

	_xelatexCommand: (mainFile) ->
		LatexRunner._latexmkBaseCommand.concat [
			"-xelatex", "-e", "$pdflatex='xelatex -synctex=1 -interaction=batchmode %O %S'",
			Path.join("$COMPILE_DIR", mainFile)
		]

	_lualatexCommand: (mainFile) ->
		LatexRunner._latexmkBaseCommand.concat [
			"-pdf", "-e", "$pdflatex='lualatex -synctex=1 -interaction=batchmode %O %S'",
			Path.join("$COMPILE_DIR", mainFile)
		]
		
	_pythonCommand: (mainFile) -> ["python", "-u", "/usr/bin/datajoy-wrapper.py", mainFile]

	_rCommand: (mainFile) -> ["Rscript", "/usr/bin/datajoy-wrapper.R", mainFile]
	
	_aptGetInstallCommand: (pkg) -> ["python", "-u", "/usr/bin/datajoy-apt-get-install.py", pkg]

	_packageInstallCommand: (pkg, source) -> ['python', '-u', '/usr/bin/datajoy-install-package.py', source, pkg]
