express = require("express")
app = express()
bodyParser = require('body-parser')

app.use(bodyParser.json())

module.exports = MockProjectHistoryApi =
	labels: { }

	setLabel: (project_id, label) ->
		@labels[project_id] ?= []
		@labels[project_id].push(label)

	getLabels: (project_id) ->
		@labels[project_id.toString()]

	reset: () ->
		@labels = {}

	run: () ->
		app.post "/project/:project_id/user/:user_id/labels", (req, res, next) =>
			{project_id, user_id } = req.params
			{version, comment, created_at} = req.body
			label = { user_id, version, comment, created_at }
			@setLabel(project_id, label)
			res.json label

		app.listen 3054, (error) ->
			throw error if error?
		.on "error", (error) ->
			console.error "error starting MockOverleafApi:", error.message
			process.exit(1)

MockProjectHistoryApi.run()
