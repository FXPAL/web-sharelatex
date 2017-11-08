settings = require 'settings-sharelatex'
logger = require 'logger-sharelatex'
oAuthRequest = require '../OAuth/OAuthRequest'

module.exports = ProjectListGetter =
	findAllUsersProjects: (userId, callback = (error, projects) ->) ->
		oAuthRequest userId, {
			url: "#{settings.overleaf.host}/api/v1/sharelatex/docs"
			method: 'GET'
			json: true
			qs:
				per: 100 # Restrict number of projects to 100, working around potential perf problems
		}, (error, docs) ->
			return callback(error) if error?
			logger.log {userId, docs}, "got projects from V1"
			callback(null, docs)