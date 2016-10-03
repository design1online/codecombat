User = require '../../../server/models/User'
Client = require '../../../server/models/Client'
OAuthProvider = require '../../../server/models/OAuthProvider'
utils = require '../utils'
nock = require 'nock'
request = require '../request'

describe 'POST /api/users', ->

  url = utils.getURL('/api/users')

  beforeEach utils.wrap (done) ->
    @client = new Client()
    @secret = @client.generateNewSecret()
    @auth = { user: @client.id, pass: secret }
    yield client.save()
    done()

  it 'creates a user that is marked as having been created by the API client', utils.wrap (done) ->
    json = { name: 'name', email: 'e@mail.com' }
    [res, body] = yield request.postAsync({url, json, @auth})
    expect(res.statusCode).toBe(201)
    expect(body.clientCreator).toBe(@client.id)
    expect(body.name).toBe(json.name)
    expect(body.email).toBe(json.email)
    done()

  
describe 'POST /api/users/oauth-identities', ->

  beforeEach utils.wrap (done) ->
    yield utils.clearModels([User, Client])
    @client = new Client()
    @secret = @client.generateNewSecret()
    yield @client.save()
    @auth = { user: @client.id, pass: @secret }
    url = utils.getURL('/api/users')
    json = { name: 'name', email: 'e@mail.com' }
    [res, body] = yield request.postAsync({url, json, @auth})
    @user = yield User.findById(res.body._id)
    @url = utils.getURL("/api/users/#{@user.id}/oauth-identities")
    @provider = new OAuthProvider({lookupUrlTemplate: 'https://oauth.provider/user?t=<%= accessToken %>'})
    @provider.save()
    @json = { provider: @provider.id, accessToken: '1234' }
    @providerRequest = nock('https://oauth.provider').get('/user?t=1234')
    done()

  it 'adds a new identity to the user if everything checks out', utils.wrap (done) ->
    @providerRequest.reply(200, {id: 'abcd'})
    [res, body] = yield request.postAsync({ @url, @json, @auth })
    expect(res.statusCode).toBe(200)
    expect(res.body.oAuthIdentities.length).toBe(1)
    expect(res.body.oAuthIdentities[0].id).toBe('abcd')
    expect(res.body.oAuthIdentities[0].provider).toBe(@provider.id)
    done()

