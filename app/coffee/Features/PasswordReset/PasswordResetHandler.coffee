settings = require("settings-sharelatex")
async = require("async")
UserGetter = require("../User/UserGetter")
OneTimeTokenHandler = require("../Security/OneTimeTokenHandler")
EmailHandler = require("../Email/EmailHandler")
AuthenticationManager = require("../Authentication/AuthenticationManager")
logger = require("logger-sharelatex")
V1Api = require("../V1/V1Api")

module.exports = PasswordResetHandler =

	generateAndEmailResetToken:(email, callback = (error, exists) ->)->
		PasswordResetHandler._getPasswordResetData email, (error, exists, data) ->
			if error? or !exists
				return callback(error, exists) 
			OneTimeTokenHandler.getNewToken 'password', data, (err, token)->
				if err then return callback(err)
				emailOptions =
					to : email
					setNewPasswordUrl : "#{settings.siteUrl}/user/password/set?passwordResetToken=#{token}&email=#{encodeURIComponent(email)}"
				EmailHandler.sendEmail "passwordResetRequested", emailOptions, (error) ->
					return callback(error) if error?
					callback null, true

	setNewUserPassword: (token, password, callback = (error, found, user_id) ->)->
		OneTimeTokenHandler.getValueFromTokenAndExpire 'password', token, (err, data)->
			if err then return callback(err)
			if !data?
				return callback null, false, null
			if typeof data == "string"
				data = { user_id: data } # backwards compatible with old format
			if data.user_id?
				AuthenticationManager.setUserPasswordInV2 data.user_id, password, (err, reset) ->
					if err then return callback(err)
					callback null, reset, data.user_id
			else if data.v1_user_id?
				AuthenticationManager.setUserPasswordInV1 {
					email: data.email,
					v1Id: data.v1_user_id,
					password: password
				}, (error, reset) ->
					return callback(error) if error?
					UserGetter.getUser { 'overleaf.id': data.v1_user_id }, {_id:1}, (error, user) ->
						return callback(error) if error?
						callback null, reset, user?._id

	_getPasswordResetData: (email, callback = (error, exists, data) ->) ->
		if settings.overleaf?
			# Overleaf v2
			V1Api.request {
				url: "/api/v1/sharelatex/user_emails"
				qs:
					email: email
				expectedStatusCodes: [404]
			}, (error, response, body) ->
				return callback(error) if error?
				if response.statusCode == 404
					return callback null, false
				else
					return callback null, true, { v1_user_id: body.user_id, email: email }
		else
			# ShareLaTeX
			UserGetter.getUserByMainEmail email, (err, user)->
				if err then return callback(err)
				if !user? or user.holdingAccount or user.overleaf?
					logger.err email:email, "user could not be found for password reset"
					return callback(null, false)
				return callback null, true, { user_id: user._id }
