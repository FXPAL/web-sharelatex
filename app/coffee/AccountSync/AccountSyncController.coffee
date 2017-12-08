logger = require('logger-sharelatex')
AccountSyncManager = require './AccountSyncManager'


module.exports = AccountSyncController =

	syncHook: (req, res, next) ->
		try
			overleafUserId = parseInt(req.params.user_id)
		catch err
			logger.err {err},
				"[AccountSync] error parsing overleaf user id from route"
			return next(err)
		setTimeout(AccountSyncManager.doSync, 1000, overleafUserId)
		return res.sendStatus(200)
