logger = require "logger-sharelatex"
ProjectImporter = require "./ProjectImporter"
AuthenticationController = require "../../../../../app/js/Features/Authentication/AuthenticationController"

module.exports = ProjectImportController =
	importProject: (req, res, next) ->
		{ol_doc_id} = req.params
		user_id = AuthenticationController.getLoggedInUserId req
		logger.log {user_id, ol_doc_id}, "importing project from overleaf"
		ProjectImporter.importProject ol_doc_id, user_id, (error, sl_project_id) ->
			return next(error) if error?
			res.json({ redir: "/project/#{sl_project_id}" })