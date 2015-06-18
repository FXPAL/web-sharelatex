AuthenticationController = require "../../../../app/js/Features/Authentication/AuthenticationController"
MendeleyAuthHandler = require("./MendeleyAuthHandler")
ReferencesApiHandler = require("./ReferencesApiHandler")

module.exports =
	apply: (app) ->
		app.get '/mendeley/oauth', AuthenticationController.requireLogin(),  ReferencesApiHandler.startAuth
		app.get '/mendeley/oauth/token-exchange', AuthenticationController.requireLogin(),  ReferencesApiHandler.completeAuth
		app.post '/mendeley/unlink', AuthenticationController.requireLogin(),  MendeleyAuthHandler.unlink
		app.get '/mendeley/reindex', AuthenticationController.requireLogin(),  ReferencesApiHandler.reindex