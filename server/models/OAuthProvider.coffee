mongoose = require 'mongoose'
plugins = require '../plugins/plugins'
log = require 'winston'
config = require '../../server_config'
jsonSchema = require '../../app/schemas/models/oauth-provider.schema.coffee'
co = require 'co'

OAuthProviderSchema = new mongoose.Schema(body: String, {strict: false,read:config.mongo.readpref})

OAuthProviderSchema.statics.jsonSchema = jsonSchema
OAuthProviderSchema.statics.editableProperties = [
  'name'
]

OAuthProviderSchema.methods.lookupAccessToken = co.wrap (accessToken) ->
  request = require('request')
  url = _.template(@get('lookupUrlTemplate'))({accessToken})
  [res, body] = yield request.getAsync({url, json: true})
  if res.statusCode >= 400
    return null
  return body

module.exports = OAuthProvider = mongoose.model('OAuthProvider', OAuthProviderSchema)
