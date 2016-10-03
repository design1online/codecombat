errors = require '../commons/errors'
wrap = require 'co-express'
database = require '../commons/database'
Client = require '../models/Client'

newSecret = wrap (req, res, next) ->
  client = yield database.getDocFromHandle(req, Client)
  if not client
    throw new errors.NotFound('Client not found.')
  secret = client.generateNewSecret()
  yield client.save()
  res.status(200).send({ secret })

module.exports = {
  newSecret
}
