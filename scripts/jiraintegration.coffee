# Configuration:
#   HUBOT_JIRA_URL
#   HUBOT_JIRA_USER
#   HUBOT_JIRA_PASSWORD
#
# Commands:
#   <Project Key>-<Issue ID> - Displays information about the JIRA ticket (if it exists)
#   hubot show watchers for <Issue Key> - Shows watchers for the given JIRA issue


module.exports = (robot) ->

  get = (msg, where, cb) ->
    console.log(process.env.HUBOT_JIRA_URL + "/rest/api/latest/" + where)

    httprequest = msg.http(process.env.HUBOT_JIRA_URL + "/rest/api/latest/" + where)
    if (process.env.HUBOT_JIRA_USER)
      authdata = new Buffer(process.env.HUBOT_JIRA_USER+':'+process.env.HUBOT_JIRA_PASSWORD).toString('base64')
      httprequest = httprequest.header('Authorization', 'Basic ' + authdata)
      
    httprequest.get() (err, res, body) ->
      if err
        res.send "GET failed :( #{err}"
        return

      if res.statusCode is 200
        cb JSON.parse(body)
      else
        console.log("res.statusCode = " + res.statusCode)
        console.log("body = " + body)

  watchers = (msg, issue, cb) ->
    get msg, "issue/#{issue}/watchers", (watchers) ->
      if watchers.errors?
        return

      cb watchers.watchers.map((watcher) -> return watcher.displayName).join(", ")

  info = (msg, issue, cb) ->
    get msg, "issue/#{issue}", (issues) ->
      if issues.errors?
        return

      issue =
          key: issues.key
          summary: issues.fields.summary
          assignee: ->
            if issues.fields.assignee != null
              issues.fields.assignee.displayName
            else
              "no assignee"
          status: issues.fields.status.name
          fixVersion: ->
            if issues.fields.fixVersions? and issues.fields.fixVersions.length > 0
              issues.fields.fixVersions.map((fixVersion) -> return fixVersion.name).join(", ")
            else
              "no fix version"
          url: process.env.HUBOT_JIRA_URL + '/browse/' + issues.key  

      cb "\n *Issue key*:- #{issue.key} \n *Issue Summary*:- #{issue.summary} \n *Issue Assignee* :-  #{issue.assignee()} \n *Issue Status* :-  #{issue.status} \n *Release* :- #{issue.fixVersion()} \n `More Details can be viewed` @ #{issue.url}"

  robot.respond /(show )?watchers (for )?(\w+-[0-9]+)/i, (msg) ->
    if msg.message.user.id is robot.name
      return

    watchers msg, msg.match[3], (text) ->
      msg.send text

  robot.respond /([^\w\-]|^)(\w+-[0-9]+)(?=[^\w]|$)/ig, (msg) ->
    if msg.message.user.id is robot.name
      return

    for matched in msg.match
      ticket = (matched.match /(\w+-[0-9]+)/)[0]
      info msg, ticket, (text) ->
          msg.send text

