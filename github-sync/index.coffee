GithubSyncRouter = require "./app/js/GithubSyncRouter"

module.exports = GithubSync =
	router: GithubSyncRouter
	
	viewIncludes:
		"userSettings": "user/_settings"
