logger = require("logger-sharelatex")
DropboxWebhookHandler = require("./DropboxWebhookHandler")

module.exports = DropboxWebhookController =
	verify: (req, res, next = (error) ->) ->
		req.session?.destroy() # don't create sessions for dropbox polling
		res.send(req.query.challenge)
		
	webhook: (req, res, next = (error) ->) ->
		req.session?.destroy() # don't create sessions for dropbox polling
		dropbox_uids = req.body?.delta?.users
		logger.log dropbox_uids: dropbox_uids, "received webhook request from Dropbox"
		if !dropbox_uids?
			return res.sendStatus(400) # Bad Request
			
		# Do this in the background so as not to keep Dropbox waiting
		DropboxWebhookHandler.pollDropboxUids dropbox_uids, (error) ->
			if error?
				logger.error err: error, dropbox_uids: dropbox_uids, "error in webhook"
		
		res.sendStatus(200)
