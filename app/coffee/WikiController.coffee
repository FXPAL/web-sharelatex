request = require("request")
settings = require("settings-sharelatex")
logger = require("logger-sharelatex")
ErrorController = require "../../../../app/js/Features/Errors/ErrorController"
_ = require("underscore")
AuthenticationController = require("../../../../app/js/Features/Authentication/AuthenticationController")
metrics = require "metrics-sharelatex"

async = require("async")
other_lngs = ["es"]
path = require("path")
Url = require "url"

baseWikiUrl = settings.apis.wiki?.url or "https://learn.sharelatex.com"


module.exports = WikiController = 

	getPage: (req, res, next) ->
		metrics.inc("wiki.getPage")
		page = Url.parse(req.url).pathname
		page = page.replace(/^\/learn/, "").replace(/^\//, "")
		preview = req.query.preview?
		if page == ""
			page = "Main_Page"

		isFile = page.toLowerCase().indexOf("file:") != -1

		mediaWikiPages = ["help:", "special:", "template:"]
		isMediaWikiPage = _.some mediaWikiPages, (substring)->
			return page.toLowerCase().indexOf(substring) != -1

		if isMediaWikiPage
			return ErrorController.notFound(null, res)

		if isFile
			return WikiController.proxy(req, res, next)

		logger.log page: page, "getting page from wiki"
		if _.include(other_lngs, req.lng)
			lngPage = "#{page}_#{req.lng}"
		else
			lngPage = page
		jobs =
			contents: (cb)-> 
				WikiController._getPageContent "Contents", cb
			pageData: (cb)->
				WikiController._getPageContent lngPage, cb
		async.parallel jobs, (error, results)->
			return next(error) if error?
			{pageData, contents} = results
			if pageData.content?.length > 280
				if _.include(other_lngs, req.lng)
					pageData.title = pageData.title.slice(0, pageData.title.length - (req.lng.length+1) )
					
				pageData.title = (pageData.title or "").split("/").pop()
				
				# '.'s mess up translation keys
				# See https://github.com/i18next/i18next-node/issues/78
				pageData.title = pageData.title.replace(/\./g, "")
					
				WikiController._renderPage(pageData, contents, preview, res)
			else
				WikiController._getPageContent page, (error, pageData) ->
					return next(error) if error?
					WikiController._renderPage(pageData, contents, preview, res)


	# only used for docker image
	proxy: (req, res, next)->
		metrics.inc("wiki.proxy")
		url = "#{baseWikiUrl}#{req.url}"
		logger.log url:url, "proxying page request to learn wiki"
		oneMinute = 1000 * 60
		urlStream = request.get({url: url, timeout: oneMinute})

		urlStream.on "error", (error) ->
			return next(error)

		urlStream.pipe(res)

	_getPageContent: (page, callback = (error, data = { content: "", title: "" }) ->) ->
		# @param {string} page
		request {
			url: "#{baseWikiUrl}/learn-scripts/api.php"
			qs: {
				page: decodeURIComponent(page)
				action: "parse"
				format: "json"
				redirects: true
			}
		}, (err, response, data)->
			return callback(err) if err?
			try
				data = JSON.parse(data)
			catch err
				logger.err err:err, data:data, "error parsing data from wiki"

			result = 
				categories: data?.parse?.categories.map (category) -> category['*']
				content: data?.parse?.text?['*']
				title: data?.parse?.title
				revid: data?.parse?.revid
				redirects: data?.parse?.redirects
			callback null, result


	_renderPage: (page, contents, preview, res)->
		if 'Draft' in page.categories and !preview
			return ErrorController.notFound(null, res)
		if page.redirects?.length > 0
			return res.redirect "/learn/#{encodeURIComponent(page.redirects[0].to)}"
		if page.revid == 0
			return ErrorController.notFound(null, res)
		
		if page.title == "Main Page"
			title = "Documentation"
		else
			title = page.title
		viewPath = path.join(__dirname, "../views/page")
		if settings.cdn?.wiki?.host?
			page.content = page?.content?.replace(/src="(\/[^"]+)"/g, "src='#{settings.cdn?.web?.host}$1'");
		res.render viewPath, {
			page: page
			contents: contents
			title: title
			meta: "A comprehensive LaTeX guide with easy to understand examples and how-tos."
		}
