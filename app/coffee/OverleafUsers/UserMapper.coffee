{User} = require "../../../../../app/js/models/User"
{UserStub} = require "../../../../../app/js/models/UserStub"
UserCreator = require "../../../../../app/js/Features/User/UserCreator"

# When we import a project, it may refer to collaborators which
# have not yet linked their account the beta system. In that case,
# we create a UserStub, so that we can insert an id into the project
# collaborators array, which is linked to an OL user id by the UserStub.
# When that user eventually migrates their account to the beta, we
# check if they have a UserStub, and if so make sure their beta User
# is created with that same id, and the UserStub deleted. Their user
# will then be linked to all the right things (projects, history, chat, etc)
# without having to modify each of this individually.
module.exports = UserMapper =
	getCanonicalEmail: (email) ->
		return email.trim().toLowerCase()

	# Given an OL user id, find the corresponding SL User id or UserStub id.
	# If no User or UserStub exists, create a UserStub. This guarantees to
	# return a SL id that will be used for this OL user forever going forwards.
	getSlIdFromOlUser: (ol_user, callback = (error, sl_user_id) ->) ->
		User.findOne { "overleaf.id": ol_user.id }, { _id: 1 }, (error, user) ->
			return callback(error) if error?
			return callback(null, user._id) if user?
			UserStub.update {
				"overleaf.id": ol_user.id
			}, {
				email: ol_user.email
			}, {
				upsert:true
			}, (error, user_stub) ->
				return callback(error) if error?
				UserStub.findOne { "overleaf.id": ol_user.id }, { _id: 1 }, (error, user_stub) ->
					return callback(error) if error?
					return callback(null, user_stub._id)
	
	getOlUserStub: (ol_user_id, callback = (error, user_stub) ->) ->
		UserStub.findOne { "overleaf.id": ol_user_id }, callback
	
	removeOlUserStub: (ol_user_id, callback = (error) ->) ->
		UserStub.remove { "overleaf.id": ol_user_id }, callback

	# Create an SL User object for the OL user, with the same ID as was
	# used for the UserStub if it exists.
	createSlUser: (ol_user, accessToken, refreshToken, callback = (error, sl_user) ->) ->
		email = UserMapper.getCanonicalEmail(ol_user.email)
		UserMapper.getOlUserStub ol_user.id, (error, user_stub) ->
			return callback(error) if error?
			new_user = {
				overleaf: {
					id: ol_user.id
					accessToken: accessToken
					refreshToken: refreshToken
				},
				email: email
			}
			if user_stub?
				new_user._id = user_stub._id
			UserCreator.createNewUser new_user, (error, user) ->
				return callback(error) if error?
				UserMapper.removeOlUserStub ol_user.id, (error) ->
					return callback(error) if error?
					return callback(null, user)

	mergeWithSlUser: (sl_user_id, ol_user, accessToken, refreshToken, callback = (error, sl_user) ->) ->
		# TODO: If a stub already exists, we can't set the SL user to this id, so we
		# need to migrate any projects/history using this stub to the existing SL id.
		User.findOne {_id: sl_user_id}, (error, user) ->
			return callback(error) if error?
			if user.email != UserMapper.getCanonicalEmail(ol_user.email)
				return callback(new Error('expected OL and SL account emails to match'))
			user.overleaf = {
				id: ol_user.id
				accessToken: accessToken
				refreshToken: refreshToken
			}
			user.save (error) ->
				return callback(error) if error?
				return callback null, user
