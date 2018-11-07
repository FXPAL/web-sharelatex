Project = require('../../models/Project').Project
logger = require('logger-sharelatex')
documentUpdaterHandler = require('../DocumentUpdater/DocumentUpdaterHandler')
tagsHandler = require("../Tags/TagsHandler")
async = require("async")
FileStoreHandler = require("../FileStore/FileStoreHandler")
CollaboratorsHandler = require("../Collaborators/CollaboratorsHandler")

module.exports = ProjectDeleter =

	markAsDeletedByExternalSource : (project_id, callback = (error) ->)->
		logger.log project_id:project_id, "marking project as deleted by external data source"
		conditions = {_id:project_id}
		update = {deletedByExternalDataSource:true}

		Project.update conditions, update, {}, (err)->
			require('../Editor/EditorController').notifyUsersProjectHasBeenDeletedOrRenamed project_id, ->
				callback()
				
	unmarkAsDeletedByExternalSource: (project_id, callback = (error) ->) ->
		logger.log project_id: project_id, "removing flag marking project as deleted by external data source"
		conditions = {_id:project_id.toString()}
		update = {deletedByExternalDataSource: false}
		Project.update conditions, update, {}, callback

	deleteUsersProjects: (user_id, callback)->
		logger.log {user_id}, "deleting users projects"
		Project.remove owner_ref:user_id, (error) ->
			return callback(error) if error?
			CollaboratorsHandler.removeUserFromAllProjets user_id, callback

	deleteProject: (project_id, callback = (error) ->) ->
		# archiveProject takes care of the clean-up
		ProjectDeleter.archiveProject project_id, (error) ->
			logger.log project_id: project_id, "deleting project"
			Project.remove _id: project_id, callback

	archiveProject: (project_id, callback = (error) ->)->
		logger.log project_id:project_id, "archived project from user request"
		async.series [
			(cb)->
				documentUpdaterHandler.flushProjectToMongoAndDelete project_id, cb
			(cb)->
				Project.update {_id:project_id}, { $set: { archived: true }}, cb
		], (err)->
			if err?
				logger.err err:err, "problem archived project"
				return callback(err)
			logger.log project_id:project_id, "successfully archived project from user request"
			callback()

	restoreProject: (project_id, callback = (error) ->) ->
		Project.update {_id:project_id}, { $unset: { archived: true }}, callback
