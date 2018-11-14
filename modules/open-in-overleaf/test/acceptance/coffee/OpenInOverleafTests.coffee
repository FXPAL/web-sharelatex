expect = require("chai").expect
async = require("async")
express = require("express")
{db, ObjectId} = require("../../../../../app/js/infrastructure/mongojs")
User = require("../../../../../test/acceptance/js/helpers/User")
ProjectGetter = require("../../../../../app/js/Features/Project/ProjectGetter")
ProjectEntityHandler = require "../../../../../app/js/Features/Project/ProjectEntityHandler"

MockProjectHistoryApi = require('../../../../../test/acceptance/js/helpers/MockProjectHistoryApi')
MockDocUpdaterApi = require('../../../../../test/acceptance/js/helpers/MockDocUpdaterApi')
MockFileStoreApi = require ('../../../../../test/acceptance/js/helpers/MockFileStoreApi')
MockDocstoreApi = require('../../../../../test/acceptance/js/helpers/MockDocstoreApi')



describe "Open In Overleaf", ->
	before (done) ->
		LinkedUrlProxy = express()
		LinkedUrlProxy.get "/", (req, res, next) =>
			if req.query.url == 'http://example.org/test.tex'
				res.send("One two three four\nI declare a thumb war")
			else if req.query.url == 'http://example.org/fancyname.tex'
				res.send("""
\\documentclass[12pt]{article}
\\begin{document}
\\title{fancy name}
I have a fancy name
\\end{document}
""")
			else
				res.sendStatus(404)

		LinkedUrlProxy.listen 6543, done

	beforeEach (done) ->
		@user = new User()
		@user.login done

	describe "when creating a project from a snippet", ->
		before ->
			@uri_regex = /^\/project\/([0-9a-fA-F]{24})$/

		describe "when GETing the gateway page", ->
			it "should redirect to the root if there is no stashed request", (done) ->
				@user.request.get "/docs", (err, res, body) =>
					expect(err).not.to.exist
					expect(res.headers.location).to.equal "/"
					expect(res.statusCode).to.equal 302
					done()

		describe "when POSTing a snippet with a valid csrf token", ->
			beforeEach (done) ->
				@user.request.post
					url: "/docs"
					form:
						_csrf: @user.csrfToken
						snip: "test"
				, (_err, _res, _body) =>
					@err = _err
					@res = _res
					@body = _body
					done()

			it "should not produce an error", ->
				expect(@err).not.to.exist

			it "should redirect to a project", ->
				expect(@res.statusCode).to.equal 302
				expect(@res.headers.location).to.match @uri_regex

			it "should create a project with the returned id", (done) ->
				projectId = @res.headers.location.match(@uri_regex)[1]
				expect(projectId).to.exist
				ProjectGetter.getProject projectId, (error, project) ->
					return done(error) if error?

					expect(project).to.exist

					done()

		describe "when POSTing a snippet which specifies a compiler", ->
			beforeEach (done) ->
				@user.request.post
					url: "/docs"
					form:
						_csrf: @user.csrfToken
						snip: "test"
						engine: "latex_dvipdf"
				, (_err, _res, _body) =>
					@err = _err
					@res = _res
					@body = _body
					done()

			it "should create a project with the requested compiler", (done) ->
				projectId = @res.headers.location.match(@uri_regex)[1]
				expect(projectId).to.exist
				ProjectGetter.getProject projectId, (error, project) ->
					return done(error) if error?

					expect(project).to.exist
					expect(project.compiler).to.equal "latex"

					done()

		describe "when GETing with a snippet in the query", ->
			beforeEach (done) ->
				@user.request.get "/docs?snip=test"
				, (_err, _res, _body) =>
					@err = _err
					@res = _res
					@body = _body
					done()

			it "should render the gateway page", ->
				expect(@err).not.to.exist
				expect(@res.headers.location).not.to.exist
				expect(@res.statusCode).to.equal 200

			it "should allow rendering of the gateway page without redirecting", (done) ->
				@user.request.get "/docs", (err, res, body) =>
					expect(err).not.to.exist
					expect(res.headers.location).not.to.exist
					expect(res.statusCode).to.equal 200
					done()

			it "should put the snippet in the session, and allow creation with just a csrf token", (done) ->
				@user.request.post
					url: "/docs"
					form:
						_csrf: @user.csrfToken
				, (err, res, body) =>
					expect(err).not.to.exist
					expect(res.statusCode).to.equal 302
					expect(res.headers.location).to.match @uri_regex
					done()

		describe "when GETing with a csrf token", ->
			beforeEach (done) ->
				@user.request.get "/docs?snip=test?_csrf=#{@user.csrfToken}"
				, (_err, _res, _body) =>
					@err = _err
					@res = _res
					@body = _body
					done()

			it "should render the gateway page", ->
				expect(@err).not.to.exist
				expect(@res.headers.location).not.to.exist
				expect(@res.statusCode).to.equal 200

		describe "when POSTing a snippet without a csrf token", ->
			beforeEach (done) ->
				@user.request.post
					url: "/docs"
					form:
						_csrf: "badtoken"
						snip: "test"
				, (_err, _res, _body) =>
					@err = _err
					@res = _res
					@body = _body
					done()

			it "should render to the gateway page", ->
				expect(@err).not.to.exist
				expect(@res.headers.location).not.to.exist
				expect(@res.statusCode).to.equal 200

			it "should allow rendering of the gateway page without redirecting", (done) ->
				@user.request.get "/docs", (err, res, body) =>
					expect(err).not.to.exist
					expect(res.headers.location).not.to.exist
					expect(res.statusCode).to.equal 200
					done()

			it "should put the snippet in the session, and allow creation with just a csrf token", (done) ->
				@user.request.post
					url: "/docs"
					form:
						_csrf: @user.csrfToken
				, (err, res, body) =>
					expect(err).not.to.exist
					expect(res.statusCode).to.equal 302
					expect(res.headers.location).to.match @uri_regex
					done()

		describe "when POSTing a snippet for a non-logged-in user", ->
			it "should redirect to the login page", (done) ->
				guest = new User()
				guest.request.post
					url: "/docs"
					form:
						_csrf: guest.csrfToken
						snip: "test"
				, (err, res, body) =>
					expect(err).not.to.exist
					expect(res.statusCode).to.equal 302
					expect(res.headers.location).to.match /login/
					done()

		describe "when POSTing without a snippet", ->
			it "should redirect to the root", (done) ->
				@user.request.post
					url: "/docs"
					form:
						_csrf: @user.csrfToken
				, (err, res, body) =>
					expect(err).not.to.exist
					expect(res.statusCode).to.equal 302
					expect(res.headers.location).to.equal "/"
					done()

		describe "when POSTing an encoded snippet with valid csrf", ->
			beforeEach (done) ->
				@user.request.post
					url: "/docs"
					form:
						_csrf: @user.csrfToken
						encoded_snip: "%22wombat%5C%7B%5C%26%5C%7D%22"
				, (_err, _res, _body) =>
					@err = _err
					@res = _res
					@body = _body
					done()

			it "should not produce an error", ->
				expect(@err).not.to.exist

			it "should redirect to a project", ->
				expect(@res.statusCode).to.equal 302
				expect(@res.headers.location).to.match @uri_regex

			it "should create a project containing the decoded snippet", (done) ->
				projectId = @res.headers.location.match(@uri_regex)[1]
				expect(projectId).to.exist
				ProjectGetter.getProject projectId, (error, project) ->
					return done(error) if error?

					expect(project).to.exist
					ProjectEntityHandler.getDoc project._id, project.rootDoc_id, (error, lines) ->
						return done(error) if error?

						expect(lines).to.include '"wombat\\{\\&\\}"'

						done()

		describe "when POSTing a snip_uri with valid csrf", ->
			beforeEach (done) ->
				@user.request.post
					url: "/docs"
					form:
						_csrf: @user.csrfToken
						snip_uri: 'http://example.org/test.tex'
				, (_err, _res, _body) =>
					@err = _err
					@res = _res
					@body = _body
					done()

			it "should not produce an error", ->
				expect(@err).not.to.exist

			it "should redirect to a project", ->
				expect(@res.statusCode).to.equal 302
				expect(@res.headers.location).to.match @uri_regex

			it "should create a project containing the retrieved snippet", (done) ->
				projectId = @res.headers.location.match(@uri_regex)[1]
				expect(projectId).to.exist
				ProjectGetter.getProject projectId, (error, project) ->
					return done(error) if error?

					expect(project).to.exist
					ProjectEntityHandler.getDoc project._id, project.rootDoc_id, (error, lines) ->
						return done(error) if error?

						expect(lines).to.include 'One two three four'

						done()

		describe "when POSTing a snip_uri that does not exist", ->
			beforeEach (done) ->
				@user.request.post
					url: "/docs"
					form:
						_csrf: @user.csrfToken
						snip_uri: 'http://example.org/test.texx'
				, (_err, _res, _body) =>
					@err = _err
					@res = _res
					@body = _body
					done()

			it "should return an error", ->
				expect(@res.statusCode).to.equal 500

		describe "when the document has a title", ->
			beforeEach (done) ->
				@user.request.post
					url: "/docs"
					form:
						_csrf: @user.csrfToken
						snip_uri: 'http://example.org/fancyname.tex'
				, (_err, _res, _body) =>
					@err = _err
					@res = _res
					@body = _body
					done()

			it "should create a project with the correct name", (done) ->
				projectId = @res.headers.location.match(@uri_regex)[1]
				expect(projectId).to.exist
				ProjectGetter.getProject projectId, (error, project) ->
					return done(error) if error?

					expect(project.name).to.equal "fancy name"
					done()

			it "should ensure that the project name is unique", (done) ->
				projectId = @res.headers.location.match(@uri_regex)[1]
				expect(projectId).to.exist
				@user.request.post
					url: "/docs"
					form:
						_csrf: @user.csrfToken
						snip_uri: 'http://example.org/fancyname.tex'
				, (err, res, body) =>
					expect(err).not.to.exist
					newProjectId = res.headers.location.match(@uri_regex)[1]
					expect(newProjectId).to.exist

					ProjectGetter.getProject newProjectId, (error, project) ->
						return done(error) if error?

						expect(project.name).to.match /fancy name.+/
						done()