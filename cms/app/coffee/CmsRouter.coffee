logger = require 'logger-sharelatex'
AboutController = require './controllers/AboutController'
BlogController = require './controllers/BlogController'
GeneralController = require './controllers/GeneralController'

removeRoute = (webRouter, method, path) ->
	index = null
	for route, i in webRouter.stack
		if route?.route?.path == path
			index = i
	if index?
		logger.log method:method, path:path, index:index, 'removing route from express router'
		webRouter.stack.splice(index,1)

module.exports =
	apply: (webRouter) ->
		removeRoute webRouter, 'get', '/about'
		removeRoute webRouter, 'get', '/blog'
		removeRoute webRouter, 'get', '/blog/*'
		webRouter.get '/about', AboutController.getPage
		webRouter.get '/blog', BlogController.getBlog
		webRouter.get '/blog/page/:page', BlogController.getBlog
		webRouter.get '/blog/tagged/:tag', BlogController.getBlog
		webRouter.get '/blog/tagged/:tag/page/:page', BlogController.getBlog
		webRouter.get '/blog/:slug', BlogController.getBlogPost
		webRouter.get '/for/:slug', GeneralController.getPage