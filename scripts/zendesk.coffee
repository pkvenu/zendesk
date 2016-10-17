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
conversation = require 'hubot-conversation'

tickets_url = "https://#{process.env.HUBOT_ZENDESK_SUBDOMAIN}.zendesk.com/tickets"
room = "#{process.env.HUBOT_GLIP_ROOM}"

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
  console.log ("user method called !")
  zendesk_request msg, "#{queries.users}/#{user_id}.json", (result) ->
    if result.error
      msg.send result.description
      return
#    console.log (result)
    return result


formatted_message = (results, cb) ->

#  console.log JSON.stringify(results)

  if results.last_audits
    for audit in results.last_audits
      for event in audit.events
        event_type = event.type.toLowerCase()

#  if results.users
    for zd_user in results.users
      if zd_user.id == results.requester_id
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

    switchBoard = new conversation(robot)
    robot.router.post '/hubot/zendesk', (req, res) ->
        results = if req.body.payload? then JSON.parse req.body.payload else req.body
        envelope = user: {reply_to: parseInt(room)}
        message = formatted_message(results)
        console.log(room)
        robot.send envelope, message
        res.send 'OK'

    robot.respond /(?:zendesk|zd) (all )?tickets$/i, (msg) ->
      zendesk_request msg, queries.unsolved, (results) ->
        ticket_count = results.count
        msg.send "##{ticket_count} unsolved tickets"


    robot.respond /(?:zendesk|zd) pending tickets$/i, (msg) ->
      zendesk_request msg, queries.pending, (results) ->
        ticket_count = results.count
        msg.send "##{ticket_count} pending tickets"

    robot.respond /(?:zendesk|zd) new tickets$/i, (msg) ->
      zendesk_request msg, queries.new, (results) ->
        ticket_count = results.count
        msg.send "##{ticket_count} new tickets"

    robot.respond /(?:zendesk|zd) escalated tickets$/i, (msg) ->
      zendesk_request msg, queries.escalated, (results) ->
        ticket_count = results.count
        msg.send "##{ticket_count} escalated tickets"

    robot.respond /(?:zendesk|zd) open tickets$/i, (msg) ->
      zendesk_request msg, queries.open, (results) ->
        ticket_count = results.count
        msg.send "##{ticket_count} open tickets"

    robot.respond /(?:zendesk|zd) list (all )?tickets$/i, (msg) ->
      zendesk_request msg, queries.unsolved, (results) ->
        for result in results.results
          msg.send "[Ticket ##{result.id}](#{result.url}) - #{result.subject}"

        setTimeout () ->

          msg.reply('Want more info? yes or no')
          dialog = switchBoard.startDialog(msg)
          dialog.addChoice /yes/i, (msg2) ->
            msg2.reply('Enter Ticket number')
            dialog.addChoice /([\d]+)$/i, (msg3) ->
              ticket_id = msg3.match[1]
              zendesk_request msg3, "#{queries.tickets}/#{ticket_id}.json?include=users,organizations,last_audits", (result) ->
                if result.error
                  msg3.send result.description
                  return
                message = formatted_message(result)
                msg3.send message,
        60 * 2000

    robot.respond /(?:zendesk|zd) list new tickets$/i, (msg) ->
      zendesk_request msg, queries.new, (results) ->
        for result in results.results
          msg.send "Ticket #{result.id} is #{result.status}: #{tickets_url}/#{result.id}"

    robot.respond /(?:zendesk|zd) list pending tickets$/i, (msg) ->
      zendesk_request msg, queries.pending, (results) ->
        for result in results.results
          msg.send "Ticket #{result.id} is #{result.status}: #{tickets_url}/#{result.id}"

    robot.respond /(?:zendesk|zd) list escalated tickets$/i, (msg) ->
      zendesk_request msg, queries.escalated, (results) ->
        for result in results.results
          msg.send "Ticket #{result.id} is escalated and #{result.status}: #{tickets_url}/#{result.id}"

    robot.respond /(?:zendesk|zd) list open tickets$/i, (msg) ->
      zendesk_request msg, queries.open, (results) ->
        for result in results.results
          msg.send "Ticket #{result.id} is #{result.status}: #{tickets_url}/#{result.id}"


    robot.respond /(?:zendesk|zd) ticket ([\d]+)$/i, (msg) ->
      ticket_id = msg.match[1]
      zendesk_request msg, "#{queries.tickets}/#{ticket_id}.json?include=users,organizations,last_audits", (result) ->
        if result.error
          msg.send result.description
          return
        message = formatted_message(result)
        msg.send message

