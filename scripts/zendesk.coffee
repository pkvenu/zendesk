# Description:
#   Queries Zendesk for information about support tickets
#
# Configuration:
#   HUBOT_ZENDESK_USER
#   HUBOT_ZENDESK_PASSWORD
#   HUBOT_ZENDESK_SUBDOMAIN
#   HUBOT_GLIP_ROOM
#
# Commands:
#   hubot zendesk (all) tickets - returns the total count of all unsolved tickets. The 'all' keyword is optional.
#   hubot zendesk new tickets - returns the count of all new (unassigned) tickets
#   hubot zendesk open tickets - returns the count of all open tickets
#   hubot zendesk escalated tickets - returns a count of tickets with escalated tag that are open or pending
#   hubot zendesk pending tickets - returns a count of tickets that are pending
#   hubot zendesk list (all) tickets - returns a list of all unsolved tickets. The 'all' keyword is optional.
#   hubot zendesk list new tickets - returns a list of all new tickets
#   hubot zendesk list open tickets - returns a list of all open tickets
#   hubot zendesk list pending tickets - returns a list of pending tickets
#   hubot zendesk list escalated tickets - returns a list of escalated tickets
#   hubot zendesk ticket <ID> - returns information about the specified ticket


sys = require 'util'
tickets_url = "https://#{process.env.HUBOT_ZENDESK_SUBDOMAIN}.zendesk.com/tickets"
room = #{process.env.HUBOT_GLIP_ROOM}
queries =
  unsolved: "search.json?query=status<solved+type:ticket"
  open: "search.json?query=status:open+type:ticket"
  new: "search.json?query=status:new+type:ticket"
  escalated: "search.json?query=tags:escalated+status:open+status:pending+type:ticket"
  pending: "search.json?query=status:pending+type:ticket"
  tickets: "tickets"
  users: "users"
  organization: "organization"
  ticket_last_audit: "ticket_last_audit"

zendesk_request = (msg, url, handler) ->
  zendesk_user = "#{process.env.HUBOT_ZENDESK_USER}"
  zendesk_password = "#{process.env.HUBOT_ZENDESK_PASSWORD}"
  auth = new Buffer("#{zendesk_user}:#{zendesk_password}").toString('base64')
  zendesk_url = "https://#{process.env.HUBOT_ZENDESK_SUBDOMAIN}.zendesk.com/api/v2"

  msg.http("#{zendesk_url}/#{url}")
  .headers(Authorization: "Basic #{auth}", Accept: "application/json")
  .get() (err, res, body) ->
    if err
      msg.send "Zendesk says: #{err}"
      return

    content = JSON.parse(body)

    if content.error?
      if content.error?.title
        msg.send "Zendesk says: #{content.error.title}"
      else
        msg.send "Zendesk says: #{content.error}"
      return

    handler content

# FIXME this works about as well as a brick floats
zendesk_user = (msg, user_id) ->
  zendesk_request msg, "#{queries.users}/#{user_id}.json", (result) ->
    if result.error
      msg.send result.description
      return
    result.user

zendesk_user_organization = (msg, user_id, organization_id ) ->
  zendesk_request msg, "#{queries.users}/#{user_id}/organizations.json", (result) ->
    if result.error
      msg.send result.description
      return
    result.organization

zendesk_ticket_last_audit = (msg, user_id, organization_id ) ->
  zendesk_request msg, "#{queries.tickets}/#{ticket_id}/audit.json?sort_order=desc", (result) ->
    if result.error
      msg.send result.description
      return
    result.ticket_last_audit

formatted_message = (results, cb) ->

  for audit in results.last_audits
    for event in audit.events
      event_type = event.type.toLowerCase()

  for zd_user in results.users
    if zd_user.id == results.ticket.requester_id
      username = zd_user.name

  message = "Ticket #{event_type}ed by #{username}"
  message += "\n"
  message += "\n[Ticket ##{results.ticket.id}](#{results.ticket.url}) - #{results.ticket.subject}"
  message += "\n"
  message += "\n**Description**"
  message += "\n#{results.ticket.description}"
  message += "\n"
  message += "\n**Priority**"
  message += "\n#{results.ticket.priority}"

  return message

module.exports = (robot) ->
    robot.router.post '/hubot/zendesk', (req, res) ->
        results = if req.body.payload? then JSON.parse req.body.payload else req.body
        envelope = user: {reply_to: parseInt(room)}
        message = formatted_message(results)
        robot.send envelope, message
        res.send 'OK'

#    robot.respond /(?:zendesk|zd) (all )?tickets$/i, (msg) ->
#      zendesk_request msg, queries.unsolved, (results) ->
#        ticket_count = results.count
#        msg.send "##{ticket_count} unsolved tickets"
#
#
#    robot.respond /(?:zendesk|zd) pending tickets$/i, (msg) ->
#      zendesk_request msg, queries.pending, (results) ->
#        ticket_count = results.count
#        msg.send "##{ticket_count} pending tickets"
#
#    robot.respond /(?:zendesk|zd) new tickets$/i, (msg) ->
#      zendesk_request msg, queries.new, (results) ->
#        ticket_count = results.count
#        msg.send "##{ticket_count} new tickets"
#
#    robot.respond /(?:zendesk|zd) escalated tickets$/i, (msg) ->
#      zendesk_request msg, queries.escalated, (results) ->
#        ticket_count = results.count
#        msg.send "##{ticket_count} escalated tickets"
#
#    robot.respond /(?:zendesk|zd) open tickets$/i, (msg) ->
#      zendesk_request msg, queries.open, (results) ->
#        ticket_count = results.count
#        msg.send "##{ticket_count} open tickets"

#    robot.respond /(?:zendesk|zd) list (all )?tickets$/i, (msg) ->
#      zendesk_request msg, queries.unsolved, (results) ->
#        for result in results.results
#          message = formatted_message(result)
#          msg.send "msg"

    robot.respond /(?:zendesk|zd) ticket ([\d]+)$/i, (msg) ->
      ticket_id = msg.match[1]
      zendesk_request msg, "#{queries.tickets}/#{ticket_id}.json?include=users,organizations,last_audits", (result) ->
        if result.error
          msg.send result.description
          return
        message = formatted_message(result)
        msg.send message
