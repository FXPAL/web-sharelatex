expect = require("chai").expect
async = require("async")
express = require("express")
path = require("path")
{db, ObjectId} = require("../../../../../app/js/infrastructure/mongojs")
User = require("../../../../../test/acceptance/js/helpers/User")
ProjectGetter = require("../../../../../app/js/Features/Project/ProjectGetter")
ProjectEntityHandler = require("../../../../../app/js/Features/Project/ProjectEntityHandler")

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
			else if req.query.url == 'http://example.org/boringname.tex'
				res.send("""
\\documentclass[12pt]{article}
\\begin{document}
\\title{boring name}
I have a boring name
\\end{document}
""")
			else if req.query.url == 'http://example.org/badname.tex'
				res.send("""
\\documentclass[12pt]{article}
\\begin{document}
\\title{bad \\\\ name}
I have a bad name
\\end{document}
""")
			else if req.query.url == 'http://example.org/project.zip'
				res.sendFile path.join(__dirname, '../fixtures', 'project.zip')
			else if req.query.url == 'http://example.org/badname.zip'
				res.sendFile path.join(__dirname, '../fixtures', 'badname.zip')
			else
				res.sendStatus(404)

		LinkedUrlProxy.listen 6543, done

	beforeEach (done) ->
		@user = new User()
		@user.login done

	describe "when creating a project from a snippet", ->
		before ->
			@uri_regex = /^\/project\/([0-9a-fA-F]{24})$/

		describe "when POSTing a snippet with a valid csrf token via xhr", ->
			beforeEach (done) ->
				@user.request.post
					url: "/docs"
					form:
						_csrf: @user.csrfToken
						snip: "test"
					headers:
						'X-Requested-With': 'XMLHttpRequest'
				, (_err, _res, _body) =>
					@err = _err
					@res = _res
					@body = _body
					done()

			it "should not produce an error", ->
				expect(@err).not.to.exist

			it "should redirect to a project", ->
				expect(@res.statusCode).to.equal 200
				expect(@res.headers["content-type"]).to.match /^application\/json/
				expect(JSON.parse(@body).redirect).to.match @uri_regex

			it "should create a project with the returned id", (done) ->
				projectId = JSON.parse(@body).redirect.match(@uri_regex)[1]
				expect(projectId).to.exist
				ProjectGetter.getProject projectId, (error, project) ->
					return done(error) if error?

					expect(project).to.exist

					done()

		describe "when POSTing a snippet with a valid csrf token via a form", ->
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
				expect(@res.headers["location"]).to.match @uri_regex

			it "should create a project with the returned id", (done) ->
				projectId = @res.headers["location"].match(@uri_regex)[1]
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
					headers:
						'X-Requested-With': 'XMLHttpRequest'
				, (_err, _res, _body) =>
					@err = _err
					@res = _res
					@body = _body
					done()

			it "should create a project with the requested compiler", (done) ->
				projectId = JSON.parse(@body).redirect.match(@uri_regex)[1]
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

		describe "when POSTing a snippet for a non-logged-in user", ->
			it "should render the gateway page", (done) ->
				guest = new User()
				guest.request.post
					url: "/docs"
					form:
						_csrf: guest.csrfToken
						snip: "test"
				, (err, res, body) =>
					expect(err).not.to.exist
					expect(res.statusCode).to.equal 200
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
					headers:
						'X-Requested-With': 'XMLHttpRequest'
				, (_err, _res, _body) =>
					@err = _err
					@res = _res
					@body = _body
					done()

			it "should not produce an error", ->
				expect(@err).not.to.exist

			it "should send a json response to redirect to a project", ->
				expect(@res.statusCode).to.equal 200
				expect(@res.headers["content-type"]).to.match /application\/json/
				expect(JSON.parse(@body).redirect).to.match @uri_regex

			it "should create a project containing the decoded snippet", (done) ->
				projectId = JSON.parse(@body).redirect.match(@uri_regex)[1]
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
					headers:
						'X-Requested-With': 'XMLHttpRequest'
				, (_err, _res, _body) =>
					@err = _err
					@res = _res
					@body = _body
					done()

			it "should not produce an error", ->
				expect(@err).not.to.exist

			it "should send a json response to redirect to a project", ->
				expect(@res.statusCode).to.equal 200
				expect(@res.headers["content-type"]).to.match /application\/json/
				expect(JSON.parse(@body).redirect).to.match @uri_regex

			it "should create a project containing the retrieved snippet", (done) ->
				projectId = JSON.parse(@body).redirect.match(@uri_regex)[1]
				expect(projectId).to.exist
				ProjectGetter.getProject projectId, (error, project) ->
					return done(error) if error?

					expect(project).to.exist
					ProjectEntityHandler.getDoc project._id, project.rootDoc_id, (error, lines) ->
						return done(error) if error?

						expect(lines).to.include 'One two three four'

						done()

		describe "when POSTing a snip_uri for a zip file", ->
			beforeEach (done) ->
				@user.request.post
					url: "/docs"
					form:
						_csrf: @user.csrfToken
						snip_uri: 'http://example.org/project.zip'
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

						expect(lines).to.include 'Wombat? Wombat.'

						done()

		describe "when POSTing a zip_uri for a zip file", ->
			beforeEach (done) ->
				@user.request.post
					url: "/docs"
					form:
						_csrf: @user.csrfToken
						zip_uri: 'http://example.org/project.zip'
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

						expect(lines).to.include 'Wombat? Wombat.'

						done()

			it "should read the name from the zip's main.tex file", (done) ->
				projectId = @res.headers.location.match(@uri_regex)[1]
				expect(projectId).to.exist
				ProjectGetter.getProject projectId, (error, project) ->
					return done(error) if error?

					expect(project).to.exist
					expect(project.name).to.match /^wombat/
					done()

		describe "when POSTing a snip_uri for a zip file with an invalid name in the tex contents", ->
			beforeEach (done) ->
				@user.request.post
					url: "/docs"
					form:
						_csrf: @user.csrfToken
						snip_uri: 'http://example.org/badname.zip'
				, (_err, _res, _body) =>
					@err = _err
					@res = _res
					@body = _body
					done()

			it "should not create a project with an invalid name", (done) ->
				projectId = @res.headers.location.match(@uri_regex)[1]
				expect(projectId).to.exist
				ProjectGetter.getProject projectId, (error, project) ->
					return done(error) if error?

					expect(project).to.exist
					expect(project.name).to.match /^bad[^\\]+name/
					done()

		describe "when POSTing a snip_uri that does not exist", ->
			beforeEach (done) ->
				@user.request.post
					url: "/docs"
					form:
						_csrf: @user.csrfToken
						snip_uri: 'http://example.org/test.texx'
					headers:
						'X-Requested-With': 'XMLHttpRequest'
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
					headers:
						'X-Requested-With': 'XMLHttpRequest'
				, (_err, _res, _body) =>
					@err = _err
					@res = _res
					@body = _body
					done()

			it "should create a project with the correct name", (done) ->
				projectId = JSON.parse(@body).redirect.match(@uri_regex)[1]
				expect(projectId).to.exist
				ProjectGetter.getProject projectId, (error, project) ->
					return done(error) if error?

					expect(project.name).to.equal "fancy name"
					done()

			it "should ensure that the project name is unique", (done) ->
				projectId = JSON.parse(@body).redirect.match(@uri_regex)[1]
				expect(projectId).to.exist
				@user.request.post
					url: "/docs"
					form:
						_csrf: @user.csrfToken
						snip_uri: 'http://example.org/fancyname.tex'
					headers:
						'X-Requested-With': 'XMLHttpRequest'
				, (err, res, body) =>
					expect(err).not.to.exist
					newProjectId = JSON.parse(body).redirect.match(@uri_regex)[1]
					expect(newProjectId).to.exist

					ProjectGetter.getProject newProjectId, (error, project) ->
						return done(error) if error?

						expect(project.name).to.match /fancy name.+/
						done()

		describe "when snip_name is supplied", ->
			beforeEach (done) ->
				@user.request.post
					url: "/docs"
					form:
						_csrf: @user.csrfToken
						snip_uri: 'http://example.org/fancyname.tex'
						snip_name: 'penguin'
					headers:
						'X-Requested-With': 'XMLHttpRequest'
				, (_err, _res, _body) =>
					@err = _err
					@res = _res
					@body = _body
					done()

			it "should create a project with the correct name", (done) ->
				projectId = JSON.parse(@body).redirect.match(@uri_regex)[1]
				expect(projectId).to.exist
				ProjectGetter.getProject projectId, (error, project) ->
					return done(error) if error?

					expect(project.name).to.equal "penguin"
					done()

			it "should ensure that the project name is unique", (done) ->
				projectId = JSON.parse(@body).redirect.match(@uri_regex)[1]
				expect(projectId).to.exist
				@user.request.post
					url: "/docs"
					form:
						_csrf: @user.csrfToken
						snip_uri: 'http://example.org/fancyname.tex'
						snip_name: 'penguin'
					headers:
						'X-Requested-With': 'XMLHttpRequest'
				, (err, res, body) =>
					expect(err).not.to.exist
					newProjectId = JSON.parse(body).redirect.match(@uri_regex)[1]
					expect(newProjectId).to.exist

					ProjectGetter.getProject newProjectId, (error, project) ->
						return done(error) if error?

						expect(project.name).to.match /penguin.+/
						done()

		describe "when opening an array of files", ->
			describe "with a basic .tex and a .zip", ->
				beforeEach (done) ->
					@user.request.post
						url: "/docs"
						form:
							_csrf: @user.csrfToken
							snip_uri: [
								'http://example.org/test.tex'
								'http://example.org/project.zip'
							]
						headers:
							'X-Requested-With': 'XMLHttpRequest'
					, (_err, _res, _body) =>
						@err = _err
						@res = _res
						@body = _body
						done()

				it "should create a project with the deault project name", (done) ->
					projectId = JSON.parse(@body).redirect.match(@uri_regex)[1]
					expect(projectId).to.exist

					ProjectGetter.getProject projectId, (error, project) ->
						return done(error) if error?

						expect(project.name).to.equal "new_snippet_project"
						done()

				it "should add the .tex file as a document", (done) ->
					projectId = JSON.parse(@body).redirect.match(@uri_regex)[1]
					expect(projectId).to.exist

					ProjectGetter.getProject projectId, (error, project) ->
						return done(error) if error?

						expect(project.rootFolder[0].docs.length).to.equal 1
						expect(project.rootFolder[0].docs[0].name).to.equal 'test.tex'
						done()

				it "should add the .zip file as a file", (done) ->
					projectId = JSON.parse(@body).redirect.match(@uri_regex)[1]
					expect(projectId).to.exist

					ProjectGetter.getProject projectId, (error, project) ->
						return done(error) if error?

						expect(project.rootFolder[0].fileRefs.length).to.equal 1
						expect(project.rootFolder[0].fileRefs[0].name).to.equal 'project.zip'
						done()

			describe "when names are supplied for the files", ->
				beforeEach (done) ->
					@user.request.post
						url: "/docs"
						form:
							_csrf: @user.csrfToken
							snip_uri: [
								'http://example.org/test.tex'
								'http://example.org/project.zip'
							]
							snip_name: [
								'wombat.tex',
								'potato.zip'
							]
						headers:
							'X-Requested-With': 'XMLHttpRequest'
					, (_err, _res, _body) =>
						@err = _err
						@res = _res
						@body = _body
						done()

				it "should use the supplied filenames", (done) ->
					projectId = JSON.parse(@body).redirect.match(@uri_regex)[1]
					expect(projectId).to.exist

					ProjectGetter.getProject projectId, (error, project) ->
						return done(error) if error?

						expect(project.rootFolder[0].docs.length).to.equal 1
						expect(project.rootFolder[0].docs[0].name).to.equal 'wombat.tex'
						expect(project.rootFolder[0].fileRefs.length).to.equal 1
						expect(project.rootFolder[0].fileRefs[0].name).to.equal 'potato.zip'
						done()
