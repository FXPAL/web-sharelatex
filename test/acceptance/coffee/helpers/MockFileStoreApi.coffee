express = require("express")
bodyParser = require "body-parser"
app = express()

module.exports = MockFileStoreApi =
	files: {}

	run: () ->
		app.post "/project/:project_id/file/:file_id", (req, res, next) =>
			chunks = []
			req.on 'data', (chunk) ->
				chunks.push(chunk)

			req.on 'end', =>
				content = Buffer.concat(chunks).toString()
				{project_id, file_id} = req.params
				@files[project_id] ?= {}
				@files[project_id][file_id] = { content }
				res.sendStatus 200

		app.get "/project/:project_id/file/:file_id", (req, res, next) =>
			{project_id, file_id} = req.params
			{ content } = @files[project_id][file_id]
			res.send content

		# handle file copying
		app.put "/project/:project_id/file/:file_id", bodyParser.json(), (req, res, next) =>
			{project_id, file_id} = req.params
			source = req.body.source
			{content} = @files[source.project_id]?[source.file_id]
			if !content?
				res.sendStatus 500
			else
				@files[project_id] ?= {}
				@files[project_id][file_id] = { content }
				res.sendStatus 200

		app.listen 3009, (error) ->
			throw error if error?
		.on "error", (error) ->
			console.error "error starting MockFileStoreApi:", error.message
			process.exit(1)

MockFileStoreApi.run()
