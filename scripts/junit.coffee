#Commands:
#   hubot jenkins junit <job> - Generates Junit Test Report


querystring = require 'querystring'
response = "\n"
tmpresponse = '\n'

traverse_it = (result) ->
  for prop of result 
    if typeof result[prop] == 'object'
      traverse_it result[prop]
    else if prop is 'className'
      tmpresponse += 'ClassName : ' + result[prop] + ",\t "
    else if prop is 'name'
      tmpresponse += 'TestCase Name : ' + result[prop] + ",\t"
    else if prop is 'status'
      tmpresponse += 'Status :  ' + result[prop] + "\n"
      response= tmpresponse
    else

junitReport = (msg) ->
    url = process.env.HUBOT_JENKINS_URL
    job = querystring.escape msg.match[1]
    path = "#{url}/job/#{job}/lastBuild/testReport/api/json"
    req = msg.http(path)

    if process.env.HUBOT_JENKINS_AUTH
      auth = new Buffer(process.env.HUBOT_JENKINS_AUTH).toString('base64')
      req.headers Authorization: "Basic #{auth}"

    req.header('Content-Length', 0)

    req.get() (err, res, body) ->
        if err
          msg.reply "Jenkins says: #{err}"
        else if 200 <= res.statusCode < 400 # Or, not an error code.
          junitreport = '\n'
          try
            content = JSON.parse(body)
          catch error
            msg.send error
          traverse_it content

	 # junitreport += "Junit Execution Details  \n"
          junitreport += "Junit Report for #{job}  Build : #{content.childReports[0].child.number} :\n"
          junitreport += "SUMMARY :- \n"
          junitreport += "Total Test Case Count : #{content.totalCount}\n"
          junitreport += "Total Failed Count    : #{content.failCount}\n"
          junitreport += "Total cases skipped   : #{content.skipCount}\n"
          junitreport += "Total cases passed    : #{content.childReports[0].result.passCount}\n"
          junitreport += "Time Taken for the run: #{content.childReports[0].result.duration}\n"
          junitreport += "More Details @        : #{content.childReports[0].child.url}\n"
          junitreport += "Test Suites Details :\n"

          junitreport += response
          tmpresponse = '\n'
          response = '\n'
          msg.send junitreport

        else if 404 == res.statusCode
          msg.reply "Build not found. Double check that it exists and is spelt correctly."
        else
          msg.reply "Jenkins says: Status #{res.statusCode} #{body}"


module.exports = (robot) ->
  robot.respond /j(?:enkins)? junit ([\w\.\-_ ]+)(, (.+))?/i, (msg) ->
    junitReport(msg)

    robot.jenkins = {
     junit: junitReport
    }
