logger = require("logger-sharelatex")
AuthenticationController = require "../../../../../app/js/Features/Authentication/AuthenticationController"
UserMapper = require "../OverleafUsers/UserMapper"
passport = require "passport"
Url = require "url"
Path = require "path"
Settings = require "settings-sharelatex"
jwt = require('jsonwebtoken')
FeaturesUpdater = require("../../../../../app/js/Features/Subscription/FeaturesUpdater")
Settings = require('settings-sharelatex')
{User} = require "../../../../../app/js/models/User"
UserController = require("../../../../../app/js/Features/User/UserController")
CollabratecController = require "../Collabratec/CollabratecController"

module.exports = OverleafAuthenticationController =
	saveRedir: (req, res, next) ->
		if req.query.redir?
			AuthenticationController._setRedirectInSession(req, req.query.redir)
		next()

	welcomeScreen: (req, res, next) ->
		res.render Path.resolve(__dirname, "../../views/welcome"), req.query

	showCheckAccountsPage: (req, res, next) ->
		{token} = req.query
		if !token?
			return res.redirect('/overleaf/login')

		jwt.verify token, Settings.accountMerge.secret, (error, data) ->
			if error?
				logger.err err: error, "bad token in checking accounts"
				return res.status(400).send("invalid token")

			{email} = data
			User.findOne {email}, {_id: 1}, (err, user) ->
				return callback(err) if err?
				if user?
					return res.redirect('/overleaf/login')
				else
					res.render Path.resolve(__dirname, "../../views/check_accounts"), {
						email
					}

	logout: (req, res, next) ->
		UserController._doLogout req, (err) ->
			return next(err) if err?
			# Redirect to v1 page which signs user out of v1 as well
			res.redirect Settings.overleaf.host + '/users/ensure_signed_out'

	setupUser: (req, res, next) ->
		# This will call OverleafAuthenticationManager.setupUser
		passport.authenticate("overleaf", (err, user, info) ->
			if err?
				if err.name == "TokenError"
					return res.redirect "/overleaf/login" # Token expired, try again
				else
					return next(err) 
			if info?.email_exists_in_sl
				logger.log {info}, "redirecting to sharelatex to merge accounts"
				url = OverleafAuthenticationController.prepareAccountMerge(info, req)
				return res.render Path.resolve(__dirname, "../../views/confirm_merge"), {
					email: info.profile.email
					redirect_url: url
					suppressNavbar: true
				}
			else
				return AuthenticationController.finishLogin(user, req, res, next)
		)(req, res, next)

	prepareAccountMerge: (info, req) ->
		{profile, user_id} = info
		req.session.accountMerge = {profile, user_id}
		token = jwt.sign(
			{ user_id, overleaf_email: profile.email, confirm_merge: true },
			Settings.accountMerge.secret,
			{ expiresIn: '1h' }
		)
		url = Settings.accountMerge.sharelatexHost + Url.format({
			pathname: "/user/confirm_account_merge",
			query: {token}
		})
		return url

	confirmedAccountMerge: (req, res, next) ->
		{token} = req.query
		if !token?
			return OverleafAuthenticationController._badToken(res, new Error('no token provided'))
		jwt.verify token, Settings.accountMerge.secret, (error, data) ->
			return OverleafAuthenticationController._badToken(res, error) if error?
			if !data.merge_confirmed
				return OverleafAuthenticationController._badToken(
					res, new Error('expected token.confirm_merge == true')
				)
			{profile, user_id} = req.session.accountMerge
			if data.user_id != user_id
				return OverleafAuthenticationController._badToken(
					res, new Error('expected token.user_id == session.accountMerge.user_id')
				)
			logger.log(
				{profile, user_id},
				"merging OL user with existing SL account"
			)
			UserMapper.mergeWithSlUser user_id, profile, (error, user) ->
				return next(error) if error?
				FeaturesUpdater.refreshFeatures(user_id) # Notifies v1 about SL-granted features too
				logger.log {user: user}, "merged with SL account, logging in"
				CollabratecController._completeOauthLink req, user, (err, linked) ->
					return callback err if err?
					if Settings.createV1AccountOnLogin and !linked
						AuthenticationController._setRedirectInSession(req, '/login/sharelatex/finish?had_v1_account')
					AuthenticationController.finishLogin(user, req, res, next)

	_badToken: (res, error) ->
		logger.err err: error, "bad token in confirming account"
		res.status(400).send("invalid token")
