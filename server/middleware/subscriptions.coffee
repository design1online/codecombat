errors = require '../commons/errors'
wrap = require 'co-express'
Prepaid = require '../models/Prepaid'
log = require 'winston'

subscribeWithPrepaidCode = wrap (req, res) ->
  { ppc } = req.body
  unless ppc and _.isString(ppc)
    throw new errors.UnprocessableEntity('You must provide a valid prepaid code.')

  # Check if code exists and has room for more redeemers
  prepaid = yield Prepaid.findOne({ code: ppc })
  unless prepaid
    msg = "Could not find prepaid code #{ppc}"
    log.warn "Subscription Error: #{req.user.get('slug')} (#{req.user.id}): '#{msg}'"
    throw new errors.NotFound('Prepaid not found')

  yield prepaid.redeem(req.user)
  res.send(req.user.toObject({req}))
        
module.exports = {
  subscribeWithPrepaidCode
}
