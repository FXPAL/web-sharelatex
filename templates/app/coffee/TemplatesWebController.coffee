request = require("request")
settings = require("settings-sharelatex")
logger = require("logger-sharelatex")
ErrorController = require("../../../../app/js/Features/Errors/ErrorController")
Path = require "path"

module.exports = TemplatesWebController =

	renderTemplatesIndexPage: (req, res)->
		logger.log "rendering index page of templates"
		TemplatesWebController._getDataFromTemplatesApi "/user/#{req.params.user_id}", (err, data)->
			if err? or !data?
				logger.err err:err, "something went wrong in renderTemplatesIndexPage"
				return res.send 500
			data.title = "latex_templates"
			res.render Path.resolve(__dirname, "../views/index"), data

	renerTemplateInTag: (req, res)->
		{user_id, tag_name, template_name} = req.params
		logger.log user_id:user_id, tag_name:tag_name, template_name:template_name, "rendering latex template page"
		TemplatesWebController._getDataFromTemplatesApi "/user/#{user_id}/tag/#{tag_name}/template/#{template_name}", (err, data)->
			if err? and err == 404
				return ErrorController.notFound req, res
			if err? or !data?
				logger.err err:err, user_id:user_id, tag_name:tag_name, template_name:template_name, "something went wrong in renerTemplateInTag"
				return res.send 500
			data.title = data?.template?.name
			res.render Path.resolve(__dirname, "../views/template"), data

	tagOrCanonicalPage: (req, res)->
		if req.params.template_id?
			TemplatesWebController._renderCanonicalPage(req, res)
		else if req.params.tag_name?.toLowerCase() == "all"
			TemplatesWebController._renderAllTemplatesPage(req, res)
		else if req.params.tag_name?
			TemplatesWebController._renderTagPage(req, res)
		else
			logger.log params:req.params, "problem rendering tagOrCanonicalPage"
			res.send 500

	proxyToTemplatesApi: (req, res)->
		url = req.url

		name = req.query.name or "Template"
		if req.query.inline?
			disposition = "inline"
		else
			disposition = "attachment"
		res.header({"content-disposition": "#{disposition}; filename=\"#{name.replace("\"", "-")}.#{req.params.file_type}\""})

		logger.log url:url, template_name: name, disposition: disposition, "proxying request to templates api"
		if url.indexOf("pdf") != -1 and url.indexOf("converted") == -1
			res.header "Content-Type", "application/pdf"
		getReq = request.get("#{settings.apis.templates.url}#{url}")
		getReq.pipe(res)
		getReq.on "error", (error) ->
			logger.error err: error, "templates proxy API error"
			res.send 500

	_renderCanonicalPage: (req, res)->
		current_user_id = req.session?.user?._id
		{user_id, template_id} = req.params
		logger.log current_user_id: current_user_id, user_id:user_id, template_id:template_id, "rendering template page"
		TemplatesWebController._getDataFromTemplatesApi "/user/#{user_id}/template/#{template_id}", (err, data)->
			if err? and err == 404
				return ErrorController.notFound req, res
			if err?
				logger.err err:err, user_id:user_id, template_id:template_id, "something went wrong in _renderCanonicalPage"
				return res.send 500
			data.title = data?.template?.name
			data.tag = null
			data.currentUserIsOwner = current_user_id and current_user_id == data.template.userId
			res.render Path.resolve(__dirname, "../views/template"), data

	_renderAllTemplatesPage: (req, res)->
		{user_id} = req.params
		logger.log user_id:user_id, "rendering all templates page"
		TemplatesWebController._getDataFromTemplatesApi "/user/#{user_id}/all", (err, data)->
			if err? and err == 404
				return ErrorController.notFound req, res
			if err?
				logger.err err:err, user_id:user_id, "something went wrong in _renderCanonicalPage"
				return res.send 500
			data.title = "all_templates"
			res.render Path.resolve(__dirname, "../views/tag"), data

	_renderTagPage:  (req, res)->
		{user_id, tag_name} = req.params
		logger.log user_id:user_id, tag_name:tag_name, "rendinging tag page for templates"
		TemplatesWebController._getDataFromTemplatesApi "/user/#{user_id}/tag/#{tag_name}", (err, data)->
			if err? and err == 404
				return ErrorController.notFound req, res
			if err?
				logger.err err:err, user_id:user_id, tag_name:tag_name, "something went wrong in _renderCanonicalPage"
				return res.send 500
			data.title = data?.tag?.name
			res.render Path.resolve(__dirname, "../views/tag"), data

	_getDataFromTemplatesApi: (path, callback)->
		opts =
			url: "#{settings.apis.templates.url}#{path}"
			json:true
		request.get opts, (err, response, data)->
			if response.statusCode == 404
				return callback 404
			callback err, data
