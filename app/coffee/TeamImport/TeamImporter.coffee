logger = require "logger-sharelatex"
settings = require "settings-sharelatex"
UserMapper = require "../OverleafUsers/UserMapper"
SubscriptionUpdater = require "../../../../../app/js/Features/Subscription/SubscriptionUpdater"
TeamInvitesHandler = require "../../../../../app/js/Features/Subscription/TeamInvitesHandler"
SubscriptionLocator = require("../../../../../app/js/Features/Subscription/SubscriptionLocator")
UserGetter = require('../../../../../app/js/Features/User/UserGetter')
Subscription = require("../../../../../app/js/models/Subscription").Subscription
async = require "async"

importTeam = (origV1Team, callback = (error, v2TeamId) ->) ->
	createV2TeamFromV1Team = (cb) -> createV2Team origV1Team, cb

	async.waterfall [
		createV2TeamFromV1Team,
		importTeamMembers,
		importPendingInvites,
	], (error, v1Team, v2Team) ->
		return rollback(origV1Team, error, callback) if error?
		callback(null, v2Team)

createV2Team = (v1Team, callback = (error, v1Team, v2Team) ->) ->
	UserMapper.getSlIdFromOlUser v1Team.owner, (error, teamAdminId) ->
		return callback(error) if error?

		SubscriptionLocator.getUsersSubscription teamAdminId, (error, existingSubscription) ->
			return callback(error) if error?
			return callback(new Error("User #{teamAdminId} already manages one team")) if existingSubscription?

			subscription = new Subscription(
				overleaf:
					id: v1Team.id
				admin_id: teamAdminId
				manager_ids: [teamAdminId]
				groupPlan: true
				planCode: "v1_#{v1Team.plan_name}"
				membersLimit: v1Team.n_licences
			)

			subscription.save (error) ->
				return callback(error) if error?
				logger.log {subscription}, "[TeamImporter] Created v2 team"
				return callback(null, v1Team, subscription)

importTeamMembers = (v1Team, v2Team, callback = (error, v1Team, v2Team) ->) ->
	async.map v1Team.users, UserMapper.getSlIdFromOlUser, (error, memberIds) ->
		return callback(error) if error?

		memberIds = memberIds.map (mId) -> mId.toString()

		SubscriptionUpdater.addUsersToGroup v2Team._id, memberIds, (error, updated) ->
			callback(error) if error?
			logger.log {memberIds}, "[TeamImporter] Members added to the team #{v2Team.id}"
			callback(null, v1Team, v2Team)

importPendingInvites = (v1Team, v2Team, callback = (error, v1Team, v2Team) ->) ->
	importInvite = (pendingInvite, cb) ->
		logger.log "[TeamImporter] Importing invite", pendingInvite
		TeamInvitesHandler.importInvite(v2Team, v1Team.name, pendingInvite.email,
			pendingInvite.code, pendingInvite.updated_at, cb)

	async.map v1Team.pending_invites, importInvite, (error, invites) ->
		callback(error, v1Team, v2Team)


rollback = (v1Team, originalError, callback) ->
	SubscriptionUpdater.deleteWithV1Id v1Team.id, (error) ->
		return callback(error) if error?
		return callback(originalError)

module.exports = TeamImporter =
	getOrImportTeam: (v1Team, callback = (error, v2Team) ->) ->
		SubscriptionLocator.getGroupWithV1Id v1Team.id, (error, subscription) ->
			return callback(error) if error?
			return callback(null, subscription) if subscription?

			importTeam(v1Team, callback)
