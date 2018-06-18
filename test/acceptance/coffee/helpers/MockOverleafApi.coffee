express = require("express")
app = express()
bodyParser = require('body-parser')

app.use(bodyParser.json())

DEFAULT_TEAM = {
	id: 5,
	name: "Test team",
	n_licences: 32,
	owner: {
		id: 1,
		email: "user1@example.com"
	},
	users: [
		{
			id: 1,
			email: "user1@example.com"
		}
		{
			id: 2,
			email: "user2@example.com"
		}
	],
	pending_invites: [
		{
			email: "invited@example.com",
			name: "Test user",
			code: "secret",
			plan_name: 'pro_plan',
			updated_at: new Date(),
		}
	]
}

module.exports = MockOverleafApi =
	docs: { }
	teamExports: { }

	setDoc: (doc) ->
		@docs[doc.id] = doc

	setTeams: (team) ->
		@teamExports[team.id] = team

	reset: () ->
		@docs = {}
		@teamExports = {}

	run: () ->

		# Project import routes
		app.post "/api/v1/sharelatex/docs/:ol_doc_id/export/start", (req, res, next) =>
			doc = @docs[req.params.ol_doc_id]
			if doc
				res.json doc
			else
				res.sendStatus 404

		app.post "/api/v1/sharelatex/docs/:ol_doc_id/export/confirm", (req, res, next) =>
      res.sendStatus 204

		app.post "/api/v1/sharelatex/docs/:ol_doc_id/export/cancel", (req, res, next) =>
      res.sendStatus 204

		app.get "/api/v1/sharelatex/docs/:ol_doc_id/export/history", (req, res, next) =>
			res.json exported: true


		# Team import routes
		app.post "/api/v1/sharelatex/team_exports/:team_id/", (req, res, next) =>
			teamId = req.params.team_id
			teamExport =  Object.assign({}, DEFAULT_TEAM,
				{ id: teamId, started_at: new Date() })

			@teamExports[teamExport.id] = teamExport

			res.json teamExport

		app.patch "/api/v1/sharelatex/team_exports/:team_id/", (req, res, next) =>
			teamId = parseInt(req.params.team_id)

			if teamId != 8
				teamExport = @teamExports[teamId]
				teamExport.v2_id = req.body.v2_id
				res.json teamExport
			else
				# Simulate a failure for an specific export
				res.sendStatus 500

		app.delete "/api/v1/sharelatex/team_exports/:team_id/", (req, res, next) =>
			teamId = req.params.team_id
			delete @teamExports.teamId

			res.sendStatus 204

		app.listen 5000, (error) ->
			throw error if error?
		.on "error", (error) ->
			console.error "error starting MockOverleafApi:", error.message
			process.exit(1)

MockOverleafApi.run()
