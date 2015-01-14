logger = require('logger-sharelatex')
async = require("async")
metrics = require('../../infrastructure/Metrics')
Settings = require('settings-sharelatex')
ObjectId = require('mongoose').Types.ObjectId
Project = require('../../models/Project').Project
Folder = require('../../models/Folder').Folder
ProjectEntityHandler = require('./ProjectEntityHandler')
User = require('../../models/User').User
fs = require('fs')
Path = require "path"
_ = require "underscore"

module.exports =
	createBlankProject : (owner_id, projectName, callback = (error, project) ->)->
		metrics.inc("project-creation")
		logger.log owner_id:owner_id, projectName:projectName, "creating blank project"
		rootFolder = new Folder {'name':'rootFolder'}
		project = new Project
			 owner_ref  : new ObjectId(owner_id)
			 name       : projectName
			 useClsi2   : true
		project.rootFolder[0] = rootFolder
		User.findById owner_id, "ace.spellCheckLanguage", (err, user)->
			project.spellCheckLanguage = user.ace.spellCheckLanguage
			project.save (err)->
				return callback(err) if err?
				callback err, project

	createBasicProject :  (owner_id, projectName, callback = (error, project) ->)->
		self = @
		@createBlankProject owner_id, projectName, (error, project)->
			return callback(error) if error?
			self._buildTemplate "mainbasic.tex", owner_id, projectName, "project_files",  (error, docLines)->
				return callback(error) if error?
				ProjectEntityHandler.addDoc project._id, project.rootFolder[0]._id, "main.tex", docLines, (error, doc)->
					return callback(error) if error?
					ProjectEntityHandler.setRootDoc project._id, doc._id, (error) ->
						callback(error, project)

	createExampleProject: (owner_id, projectName, callback = (error, project) ->)->
		self = @
		@createBlankProject owner_id, projectName, (error, project)->
			return callback(error) if error?
			async.series [
				(callback) ->
					self._buildTemplate "main.tex", owner_id, projectName, "project_files", (error, docLines)->
						return callback(error) if error?
						ProjectEntityHandler.addDoc project._id, project.rootFolder[0]._id, "main.tex", docLines, (error, doc)->
							return callback(error) if error?
							ProjectEntityHandler.setRootDoc project._id, doc._id, callback
				(callback) ->
					self._buildTemplate "references.bib", owner_id, projectName, "project_files", (error, docLines)->
						return callback(error) if error?
						ProjectEntityHandler.addDoc project._id, project.rootFolder[0]._id, "references.bib", docLines, (error, doc)->
							callback(error)
				(callback) ->
					universePath = Path.resolve(__dirname + "/../../../templates/project_files/universe.jpg")
					ProjectEntityHandler.addFile project._id, project.rootFolder[0]._id, "universe.jpg", universePath, callback
			], (error) ->
				callback(error, project)

	createTemplatedProject: (owner_id, projectName, templateName, done = (error, project) ->)->
		self = @
		@createBlankProject owner_id, projectName, (error, project)->
			return callback(error) if error?
			templatePath = Path.resolve(__dirname + "/../../../templates/#{templateName}")
			logger.log "creating templated project", templatePath

			async.waterfall [
				(get_files) ->
					fs.readdir templatePath, (error, files) ->
						return get_files(error) if error?
						get_files null, files
				(files, done_reading) ->
					async.eachSeries files, (file, callback) ->
						extension = Path.extname(file)
						if _.contains ['.tex'], extension
							self._buildTemplate file, owner_id, projectName, templateName, (error, docLines)->
								return callback(error) if error?
								ProjectEntityHandler.addDoc project._id, project.rootFolder[0]._id, file, docLines, (error, doc)->
									return callback(error) if error?
									ProjectEntityHandler.setRootDoc project._id, doc._id, callback
						else if _.contains ['.bib'], extension
							self._buildTemplate file, owner_id, projectName, templateName, (error, docLines)->
								return callback(error) if error?
								ProjectEntityHandler.addDoc project._id, project.rootFolder[0]._id, file, docLines, (error, doc)->
									callback(error)
						else
							logger.error file: file, error: templatePath,  file + " this is the path, now I will kill myself"
							file_path = Path.resolve(templatePath+"/#{file}")
							ProjectEntityHandler.addFile project._id, project.rootFolder[0]._id, file, file_path, callback
					, (error) ->
						done_reading(error, project)
			], (error) ->
				done(error, project)

	_buildTemplate: (template_name, user_id, project_name, project_template_name, callback = (error, output) ->)->
		User.findById user_id, "first_name last_name", (error, user)->
			return callback(error) if error?
			monthNames = [ "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" ]
			templatePath = Path.resolve(__dirname + "/../../../templates/#{project_template_name}/#{template_name}")
			fs.readFile templatePath, (error, template) ->
				return callback(error) if error?
				data =
					project_name: project_name
					user: user
					year: new Date().getUTCFullYear()
					month: monthNames[new Date().getUTCMonth()]
				output = _.template(template.toString(), data)
				callback null, output.split("\n")
