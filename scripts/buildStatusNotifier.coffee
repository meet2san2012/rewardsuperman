#Description:
#   This script listens for the various life cycle events of the jenkins build,
#   Creates Junit report and updates the build and deployment status back on the slack


url = require('url')
response = "\n"
tmpresponse = '\n'
querystring = require('querystring')

# Procedure to parse Junit Test suites
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
#    else

module.exports = (robot) ->

  robot.router.post "/hubot/jenkins-notify", (req, res) ->

    @failing ||= []
    query = querystring.parse(url.parse(req.url).query)

    res.end('')

    envelope = {notstrat:"Fs"}
    envelope.room = query.room if query.room
    envelope.notstrat = query.notstrat if query.notstrat 
    if query.type
      envelope.user = {type: query.type}

    try
      data = req.body
      console.log "data.build.phase is : #{data.build.phase} & data.build.status is :  #{data.build.status}"

      if data.build.phase == 'COMPLETED'
          if data.build.status == 'FAILURE'
             if data.name in @failing
                 build = "is still"
             else
                 build = "started"
             robot.send envelope, "#{data.name} build ##{data.build.number} #{build} *failing*. (#{encodeURI(data.build.full_url)})"
          if data.build.status == 'SUCCESS'
             if data.name in @failing
                 build = "was restored"
             else
                 build = "succeeded"
             robot.send envelope, "#{data.name} build ##{data.build.number} *#{build}* (#{encodeURI(data.build.full_url)})"
             
             jenkinsurl = process.env.HUBOT_JENKINS_URL
             job = data.name
             path = "#{jenkinsurl}/job/#{job}/lastBuild/testReport/api/json"
             req1 = robot.http(path)

             if process.env.HUBOT_JENKINS_AUTH
                auth1 = new Buffer(process.env.HUBOT_JENKINS_AUTH).toString('base64')
                req1.headers Authorization: "Basic #{auth1}"

             req1.header('Content-Length', 0)

             req1.get() (err1, res1, body1) ->
              if err1
                robot.send envelope,"Jenkins says: #{err1}"
              else if 200 <= res1.statusCode < 400 # Or, not an error code.
                junitreport = '\n'
                try
                  content1 = JSON.parse(body1)
                catch error
                  robot.send envelope, "#{error}"
                traverse_it content1

                junitreport += "`Junit Report for #{job}  build num: #{content1.childReports[0].child.number}`\n"
                junitreport += "*SUMMARY :-* \n"
                junitreport += "Total Test Case Count : #{content1.totalCount}\n"
                junitreport += "Total Failed Count    : #{content1.failCount}\n"
                junitreport += "Total cases skipped   : #{content1.skipCount}\n"
                junitreport += "Total cases passed    : #{content1.childReports[0].result.passCount}\n"
                junitreport += "Time Taken for the run: #{content1.childReports[0].result.duration}\n"
                junitreport += "More Details @        : #{content1.childReports[0].child.url}\n"
                junitreport += "*Test Suites Details :*"

                junitreport += response
                tmpresponse = '\n'
                response = '\n'
                robot.send envelope,"#{junitreport}"

              else if 404 == res1.statusCode
                robot.send envelope, "Build not found. Double check that it exists and is spelt correctly."
              else
                robot.send envelope, "Jenkins says: Status #{res.statusCode} #{body}"

      if data.build.phase == 'FINALIZED' and data.build.status == 'SUCCESS' and data.name.endsWith('Deploy')
         robot.send envelope, "#{data.name} successfully deployed (#{encodeURI(data.build.full_url)})"
    catch error
      console.log "jenkins-notify error: #{error}. Data: #{req.body}"
      console.log error.stack


