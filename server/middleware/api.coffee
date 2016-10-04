basicAuth = require('basic-auth')
Client = require '../models/Client'
User = require '../models/User'
wrap = require 'co-express'
errors = require '../commons/errors'
database = require '../commons/database'
config = require '../../server_config'
OAuthProvider = require '../models/OAuthProvider'

clientAuth = wrap (req, res, next) ->
  if config.isProduction and not req.secure  
    throw new errors.Unauthorized('API calls must be over HTTPS.')

  creds = basicAuth(req)

  unless creds and creds.name and creds.pass
    throw new errors.Unauthorized('Basic auth credentials not provided.')
    
  client = yield Client.findById(creds.name)
  if not client
    throw new errors.Unauthorized('Credentials incorrect.')
    
  hashed = Client.hash(creds.pass)
  if client.get('secret') isnt hashed
    throw new errors.Unauthorized('Credentials incorrect.')

  req.client = client
  next()

  
postUser = wrap (req, res, next) ->
  user = new User({anonymous: false})
  user.set(_.pick(req.body, 'name', 'email'))
  user.set('clientCreator', req.client._id)
  database.validateDoc(user)
  user = yield user.save()
  res.status(201).send(user.toObject({req, includedPrivates: ['email']}))
  
  
postUserOAuthIdentity = wrap (req, res) ->
  user = yield database.getDocFromHandle(req, User)
  if not user
    throw new errors.NotFound('User not found.')
    
  unless req.client._id.equals(user.get('clientCreator'))
    throw new errors.Forbidden('Must have created the user to perform this action.')
    
  { provider: providerID, accessToken } = req.body or {}
  unless providerID and accessToken
    throw new errors.UnprocessableEntity('Properties "provider" and "accessToken" required.')
    
  if not database.isID(providerID)
    throw new errors.UnprocessableEntity('"provider" is not a valid id')
    
  provider = yield OAuthProvider.findById(providerID)
  if not provider
    throw new errors.NotFound('Provider not found.')

  userData = yield provider.lookupAccessToken(accessToken)
  if not userData
    throw new errors.UnprocessableEntity('Token was invalid')
    
  identity = {
    provider: provider._id
    id: userData.id
  }

  otherUser = yield User.findOne({oAuthIdentities: { $elemMatch: identity }})
  if otherUser
    throw new errors.Conflict('User already exists with this identity')

  yield user.update({$push: {oAuthIdentities: identity}})
  oAuthIdentities = user.get('oAuthIdentities') or []
  oAuthIdentities.push(identity)
  user.set({oAuthIdentities})
  res.send(user.toObject({req}))
  
  
module.exports = {
  clientAuth
  postUser
  postUserOAuthIdentity
}
