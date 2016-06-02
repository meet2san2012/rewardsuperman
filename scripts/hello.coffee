# Commands:
#   Hello <text> - Display text back to you
#
# Author:
#   sanjay


module.exports = (robot) ->
	robot.respond /Hello(.*)/i, (msg) ->
    		msg.send msg.match[1]

