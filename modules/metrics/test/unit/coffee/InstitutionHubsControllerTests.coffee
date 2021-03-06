should = require('chai').should()
SandboxedModule = require('sandboxed-module')
assert = require('assert')
Path = require('path')
modulePath = Path.join __dirname, '../../../app/js/InstitutionHubsController'
sinon = require("sinon")
expect = require("chai").expect

describe "InstitutionHubsController", ->
	beforeEach ->
		@InstitutionHubsController = SandboxedModule.require modulePath, requires:
			'settings-sharelatex': @Settings =
				apis:
					analytics:
						url: 'http://analytics:123456'
					v1:
						url: 'some.host'
						user: 'one'
						pass: 'two'
			'request': @request = sinon.stub()
			'../../../../app/js/Features/Institutions/InstitutionsGetter': @InstitutionsGetter = {}
			'logger-sharelatex':
				err: sinon.stub()
				log: sinon.stub()
		institution =
			_id: 'mock-institution-id'
			v1Id: 5
			fetchV1Data: (callback) =>
				institution = Object.assign({}, @institution)
				institution.name = 'Stanford'
				institution.portalSlug = 'slug'
				callback(null, institution)
		@req = entity: institution
		@res = { send: sinon.stub(), header: sinon.stub(), contentType: sinon.stub() }

	describe "institutionHub rendering", ->
		it 'renders the institution hub template', (done) ->
			@res = { render: sinon.stub() }
			usageData = "{\"count\": 10}"
			recentActivity = "[{\"title\": \"yesterday\"}]"
			@InstitutionHubsController._usageData = sinon.stub().callsArgWith(1, usageData)
			@InstitutionHubsController._recentActivity = sinon.stub().callsArgWith(1, recentActivity)

			@InstitutionHubsController.institutionHub(@req, @res)
			@res.render.calledWith(
				sinon.match('views/institutionHub'), {
					institutionId: 5,
					institutionName: 'Stanford',
					portalSlug: 'slug',
					usageData: usageData,
					recentActivity: recentActivity
				}
			).should.equal true

			done()

	describe "recent activity", ->
		beforeEach ->
			@callback = sinon.stub()
			@dataResponse = {
				day: { users: 76, projects: 143 },
				week: { users: 221, projects: 513 },
				month: { users: 277, projects: 1006 },
				year: { users: 290, projects: 1220 },
				institutionId: 5
			}

		it 'fetches and formats recent activity', (done) ->
			@request.get = sinon.stub().callsArgWith(1, null, {statusCode: 200}, @dataResponse)
			@InstitutionHubsController._recentActivity(5, @callback)

			formatted = [
				{ title: 'Yesterday', users: 76, docs: 143 },
				{ title: 'Last Week', users: 221, docs: 513 },
				{ title: 'Last Month', users: 277, docs: 1006 },
				{ title: 'This Year', users: 290, docs: 1220 }
			]
			@callback.calledWith(formatted).should.equal true
			done()

		it 'returns null on errors and non-success status', (done) ->
			@request.get = sinon.stub().callsArgWith(1, null, {statusCode: 500}, {})
			@InstitutionHubsController._recentActivity(5, @callback)
			@callback.calledWith(null).should.equal true

			@request.get = sinon.stub().callsArgWith(1, 'error', {statusCode: 200}, {})
			@InstitutionHubsController._recentActivity(5, @callback)
			@callback.calledWith(null).should.equal true
			done()

		it 'returns null on errors and non-success status', (done) ->
			@request.get = sinon.stub().callsArgWith(1, null, {statusCode: 500}, {})
			@InstitutionHubsController._recentActivity(5, @callback)
			@callback.calledWith(null).should.equal true

			@request.get = sinon.stub().callsArgWith(1, 'error', {statusCode: 200}, {})
			@InstitutionHubsController._recentActivity(5, @callback)
			@callback.calledWith(null).should.equal true
			done()

		it 'returns null on zero activity', (done) ->
			@dataResponse.month.users = 0
			@dataResponse.month.projects = 0
			@request.get = sinon.stub().callsArgWith(1, null, {statusCode: 200}, @dataResponse)
			@InstitutionHubsController._recentActivity(5, @callback)
			@callback.calledWith(null).should.equal true
			done()

	describe "v1 api proxies", ->
		beforeEach ->
			@v1JsonResp = "[{\"validJson\": \"true\"}]"
			@request.get = sinon.stub().callsArgWith(1, null, null, @v1JsonResp)
			@institutionsApi = '/api/v2/institutions/'
			@v1Auth = {user: @Settings.apis.v1.user, pass: @Settings.apis.v1.pass}

		it 'calls correct endpoint for external collaboration', (done) ->
			@InstitutionHubsController.institutionExternalCollaboration(@req, @res)
			@request.get.calledWith({
				url: @Settings.apis.v1.url + @institutionsApi + '5/external_collaboration_data'
				auth: @v1Auth
				json: true
			}).should.equal true
			@res.send.calledWith(@v1JsonResp).should.equal true
			done()

		it 'calls correct endpoint for departments', (done) ->
			@req.params = { id: 5 }
			@InstitutionHubsController.institutionDepartments(@req, @res)
			@request.get.calledWith({
				url: @Settings.apis.v1.url + @institutionsApi + '5/departments_data'
				auth: @v1Auth
				json: true
			}).should.equal true
			@res.send.calledWith(@v1JsonResp).should.equal true
			done()

		it 'calls correct endpoint for roles', (done) ->
			@InstitutionHubsController.institutionRoles(@req, @res)
			@request.get.calledWith({
				url: @Settings.apis.v1.url + @institutionsApi + '5/roles_data'
				auth: @v1Auth
				json: true
			}).should.equal true
			@res.send.calledWith(@v1JsonResp).should.equal true
			done()

		it 'calls correct endpoint with query for usageData', (done) ->
			endpoint = /5\/usage_signup_data\?start_date=\d+&end_date=\d+/
			@InstitutionHubsController._usageData 5, (data) =>
				@request.get.calledWith({
					url: sinon.match(endpoint)
					auth: @v1Auth
					json: true
				}).should.equal true
				expect(data).to.deep.equal(@v1JsonResp)
				done()

		it 'calls v1 and returns csv of users', (done) ->
			v1JsonResp = [{
				'email': 'test@test.test',
				'role': 'student',
				'department': 'engineering',
				'created_at': '2018-10-08T12:53:00.058Z'
			}]
			jsonAsCSV = '"email","role","department","created_at"\n"test@test.test","student","engineering","2018-10-08T12:53:00.058Z"'
			@request.get = sinon.stub().callsArgWith(1, null, null, v1JsonResp)
			endpoint = /5\/confirmed_affiliations/
			@InstitutionHubsController.institutionUsersCSV(@req, @res)
			@request.get.calledWith({
				url: sinon.match(endpoint)
				auth: @v1Auth
				json: true
			}).should.equal true
			@res.header.calledWith('Content-Disposition', 'attachment; filename=Users.csv').should.equal true
			@res.send.calledWith(jsonAsCSV).should.equal true
			done()
