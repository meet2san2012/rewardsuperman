#Description:
#   This script submits job at jenkins, gives details of a particular jenkin job and list available jobs of Jenkins.
#
# Configuration:
#   HUBOT_JENKINS_URL
#   HUBOT_JENKINS_AUTH
#
#   Auth should be in the "user:password" format.
#
# Commands:
#   hubot jenkins build <job> - builds the specified Jenkins job
#   hubot jenkins list <filter> - lists Jenkins jobs
#   hubot jenkins describe <job> - Describes the specified Jenkins job

querystring = require 'querystring'
jobList = []

jenkinsBuild = (msg) ->
    url = process.env.HUBOT_JENKINS_URL
    job = querystring.escape msg.match[1]
    path = "#{url}/job/#{job}/build"

    req = msg.http(path)

    if process.env.HUBOT_JENKINS_AUTH
      auth = new Buffer(process.env.HUBOT_JENKINS_AUTH).toString('base64')
      req.headers Authorization: "Basic #{auth}"

    req.header('Content-Length', 0)
    req.post() (err, res, body) ->
        if err
          msg.reply "Jenkins says: #{err}"
        else if 200 <= res.statusCode < 400 # Or, not an error code.
          msg.reply "Job Name: #{job} ... Build started... More details @  #{url}/job/#{job}"
        else if 404 == res.statusCode
          msg.reply "Build not found. Double check that it exists and is spelt correctly."
        else
          msg.reply "Jenkins says: Status #{res.statusCode} #{body}"

jenkinsDescribe = (msg) ->
    url = process.env.HUBOT_JENKINS_URL
    job = msg.match[1]

    path = "#{url}/job/#{job}/api/json"

    req = msg.http(path)

    if process.env.HUBOT_JENKINS_AUTH
      auth = new Buffer(process.env.HUBOT_JENKINS_AUTH).toString('base64')
      req.headers Authorization: "Basic #{auth}"


    req.header('Content-Length', 0)
    req.get() (err, res, body) ->
        if err
          msg.send "Jenkins says: #{err}"
        else
          response = ""
          try
            content = JSON.parse(body)
            response += "JOB: #{content.displayName}\n"
            response += "URL: #{content.url}\n"
		
            if content.description
              response += "DESCRIPTION: #{content.description}\n"

            response += "ENABLED: #{content.buildable}\n"
            response += "STATUS: #{content.color}\n"

            tmpReport = ""
            if content.healthReport.length > 0
              for report in content.healthReport
                tmpReport += "\n  #{report.description}"
            else
              tmpReport = " unknown"
            response += "HEALTH: #{tmpReport}\n"

            msg.send response

            if not content.lastBuild
              return

            path = "#{url}/job/#{job}/#{content.lastBuild.number}/api/json"
            req = msg.http(path)
            if process.env.HUBOT_JENKINS_AUTH
              auth = new Buffer(process.env.HUBOT_JENKINS_AUTH).toString('base64')
              req.headers Authorization: "Basic #{auth}"

            req.header('Content-Length', 0)
            req.get() (err, res, body) ->
                if err
                  msg.send "Jenkins says: #{err}"
                else
                  response = ""
                  try
                    content = JSON.parse(body)
                    console.log(JSON.stringify(content, null, 4))
                    jobstatus = content.result || 'PENDING'
                    jobdate = new Date(content.timestamp);
                    response += "LAST JOB: #{jobstatus}, #{jobdate}\n"

                    msg.send response
                  catch error
                    msg.send error

          catch error
            msg.send error

jenkinsList = (msg) ->
    url = process.env.HUBOT_JENKINS_URL
    filter = new RegExp(msg.match[2], 'i')
    req = msg.http("#{url}/api/json")

    if process.env.HUBOT_JENKINS_AUTH
      auth = new Buffer(process.env.HUBOT_JENKINS_AUTH).toString('base64')
      req.headers Authorization: "Basic #{auth}"

    req.get() (err, res, body) ->
        response = ""
        if err
          msg.send "Jenkins says: #{err}"
        else
          try
            content = JSON.parse(body)
            for job in content.jobs
              # Add the job to the jobList
              index = jobList.indexOf(job.name)
              if index == -1
                jobList.push(job.name)
                index = jobList.indexOf(job.name)

              state = if job.color == "red"
                        "FAIL"
                      else if job.color == "aborted"
                        "ABORTED"
                      else if job.color == "aborted_anime"
                        "CURRENTLY RUNNING"
                      else if job.color == "red_anime"
                        "CURRENTLY RUNNING"
                      else if job.color == "blue_anime"
                        "CURRENTLY RUNNING"
                      else "PASS"

              if (filter.test job.name) or (filter.test state)
                response += "[#{index + 1}] #{state} #{job.name}\n"
            msg.send response
          catch error
            msg.send error

module.exports = (robot) ->
  robot.respond /j(?:enkins)? build ([\w\.\-_ ]+)(, (.+))?/i, (msg) ->
    jenkinsBuild(msg, false)

  robot.respond /j(?:enkins)? list( (.+))?/i, (msg) ->
    jenkinsList(msg)

  robot.respond /j(?:enkins)? describe (.*)/i, (msg) ->
    jenkinsDescribe(msg)

