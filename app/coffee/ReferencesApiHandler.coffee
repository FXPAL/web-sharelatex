settings = require("settings-sharelatex")
request = require("request")
thirdpartyUrl = settings.apis.thirdpartyreferences?.url || "http://localhost:3023"
referencesUrl = settings.apis.references?.url || "http://localhost:3040"
mongojs = require "mongojs"
db = mongojs(settings.mongo.url, ["users"])
ObjectId = mongojs.ObjectId
UserUpdater = require("../../../../app/js/Features/User/UserUpdater")
logger = require("logger-sharelatex")
UserGetter = require('../../../../app/js/Features/User/UserGetter')
ProjectEntityHandler = require('../../../../app/js/Features/Project/ProjectEntityHandler')
DocumentUpdaterHandler = require('../../../../app/js/Features/DocumentUpdater/DocumentUpdaterHandler')
EditorRealTimeController = require('../../../../app/js/Features/Editor/EditorRealTimeController')
AuthenticationController = require('../../../../app/js/Features/Authentication/AuthenticationController')
_ = require('underscore')
fs = require('fs')
temp = require('temp')

module.exports = ReferencesApiHandler =

	userCanMakeRequest: (userId, ref_provider, callback=(err, canMakeRequest)->) ->
		UserGetter.getUser userId, (err, user) ->
			callback(err, user?.features?.references == true)

	startAuth: (req, res, next)->
		user_id = AuthenticationController.getLoggedInUserId(req)
		ref_provider = req.params.ref_provider
		logger.log {user_id, ref_provider}, "starting references auth process"
		ReferencesApiHandler.userCanMakeRequest user_id, ref_provider, (err, canMakeRequest) ->
			if err
				logger.error {user_id, ref_provider, err}, "error determining if user can make this request"
				return next(err)
			if !canMakeRequest
				return res.send 403
			opts =
				method:"get"
				url: "/user/#{user_id}/#{ref_provider}/oauth"
				json:true
			ReferencesApiHandler.make3rdRequest opts, (err, response, body)->
				if err
					logger.error {user_id, ref_provider, err}, "error contacting tpr api"
					return next(err)
				logger.log body:body, statusCode:response.statusCode, "thirdparty return"
				res.redirect(body.redirect)

	completeAuth: (req, res, next)->
		user_id = AuthenticationController.getLoggedInUserId(req)
		ref_provider = req.params.ref_provider
		ReferencesApiHandler.userCanMakeRequest user_id, ref_provider, (err, canMakeRequest) ->
			if err
				return next(err)
			if !canMakeRequest
				return res.send 403
			opts =
				method:"get"
				url: "/user/#{user_id}/#{ref_provider}/tokenexchange"
				qs: req.query
			ReferencesApiHandler.make3rdRequest opts, (err, response, body)->
				if err
					logger.error {user_id, ref_provider, err}, "error contacting tpr api"
					return next(err)
				logger.log {user_id, ref_provider}, "auth complete"
				res.redirect "/user/settings"

	make3rdRequest: (opts, callback)->
		opts.url = "#{thirdpartyUrl}#{opts.url}"
		logger.log {url: opts.url}, 'making request to third-party-references api'
		request opts, callback

	makeRefRequest: (opts, callback)->
		opts.url = "#{referencesUrl}#{opts.url}"
		logger.log {url: opts.url}, 'making request to third-party-references api'
		request opts, callback

	unlink: (req, res, next) ->
		ref_provider = req.params.ref_provider
		user_id = AuthenticationController.getLoggedInUserId(req)

		ref = {}
		ref[ref_provider] = true
		update =
			$unset:
				refProviders:
					ref

		logger.log {user_id, update:update}, "reference unlink"
		UserUpdater.updateUser user_id, update, (err)->
			if err?
				logger.err err:err, result:result, "error unlinking reference info on user " + ref_provider
			res.redirect "/user/settings"

	bibtex: (req, res, next) ->
		user_id = AuthenticationController.getLoggedInUserId(req)
		ref_provider = req.params.ref_provider
		ReferencesApiHandler.userCanMakeRequest user_id, ref_provider, (err, canMakeRequest) ->
			if err
				return next(err)
			if !canMakeRequest
				return res.send 403
			opts =
				method:"get"
				url: "/user/#{user_id}/#{ref_provider}/bibtex"
			logger.log {user_id, ref_provider}, "getting bibtex from third-party-references"
			ReferencesApiHandler.make3rdRequest opts, (err, response, body)->
				if err
					logger.err {user_id, ref_provider}, "error getting bibtex from third-party-references"
					return next(err)
				if 200 <= response.statusCode < 300
					logger.log {user_id, ref_provider}, "got bibtex from third-party-references, returning to client"
					res.json body
				else
					logger.log {user_id, ref_provider, statusCode:response.statusCode}, "error code from remote api"
					res.send response.statusCode

	make3rdRequestStream: (opts)->
		opts.url = "#{thirdpartyUrl}#{opts.url}"
		logger.log {url: opts.url}, 'making request to third-party-references api'
		stream = request opts
		return stream

	importBibtex: (req, res, next) ->
		user_id = AuthenticationController.getLoggedInUserId(req)
		ref_provider = req.params.ref_provider
		project_id = req.params.Project_id
		ReferencesApiHandler.userCanMakeRequest user_id, ref_provider, (err, canMakeRequest) ->
			if err
				return next(err)
			if !canMakeRequest
				return res.send 403
			opts =
				method:"get"
				url: "/user/#{user_id}/#{ref_provider}/bibtex"
			logger.log {user_id, ref_provider, project_id}, "importing bibtex from third-party-references"
			# get the bibtex from remote api
			tempWriteStream = temp.createWriteStream()
			tempFilePath = tempWriteStream.path
			requestStream = ReferencesApiHandler.make3rdRequestStream opts
			# always clean up the temp file
			_cleanup = _.once(
				(cb) ->
					tempWriteStream.destroy()
					fs.unlink tempFilePath, (err) ->
						if err?
							logger.err {tempFilePath, err}, "error removing file after streaming references"
							next(err)
						else
							cb(null)
			)
			requestStream.on 'error', (err) ->
				logger.err {err, user_id, project_id, ref_provider}, "error streaming bibtex from third-party-references"
				_cleanup () ->
					return next(err)
			requestStream.on 'end', () ->
				ProjectEntityHandler.getAllFiles project_id, (err, allFiles) ->
					if err?
						logger.err {user_id, ref_provider, project_id}, "error getting all files"
						return _cleanup () ->
							next(err)
					targetFileName = "#{ref_provider}.bib"
					# check if file exists
					if file = allFiles["/#{targetFileName}"]
						# file exists already
						logger.log {user_id, ref_provider, project_id, targetFileName}, "updating file with bibtex content"
						# set document contents to the bibtex payload
						ProjectEntityHandler.replaceFile project_id, file._id, tempFilePath, (err) ->
							if err
								logger.err {user_id, ref_provider, project_id}, 'error replacing file'
								return _cleanup () ->
									next(err)
							_cleanup () ->
								res.send 201
					else
						# file is new
						logger.log {user_id, ref_provider, project_id, targetFileName}, "creating new file with bibtex content"
						# add a new doc, with bibtex payload
						ProjectEntityHandler.addFile project_id, undefined, targetFileName, tempFilePath, (err, fileRef, folder_id) ->
							if err
								logger.err {user_id, ref_provider, project_id}, 'error adding file'
								return _cleanup () ->
									next(err)
							EditorRealTimeController.emitToRoom(project_id, 'reciveNewFile', folder_id, fileRef, "references-import")
							return _cleanup () ->
								res.send 201
			requestStream.pipe tempWriteStream
