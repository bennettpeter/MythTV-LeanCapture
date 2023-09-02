#!/usr/bin/python3
# Send an email and / or text message
# Input parameters:
# Subject
# Content
# [mail, nomail] default mail

import os
import sys
import requests
from datetime import datetime
from configparser import ConfigParser
import smtplib
from email.mime.text import MIMEText
from email.utils import formatdate

scriptname="notify"
config=ConfigParser()
# In order for this to work, there must be a line [ default ] before
# other executable lines. 
# any line that is not simply var=value must be prepended with a=1;
config.read('/etc/opt/mythtv/leancapture.conf')

privConfig=ConfigParser()
privConfig.read('/etc/opt/mythtv/private.conf')

#debug lines
# print config.sections()
# print config.items(" default ")

if len(sys.argv) < 3 :
    print("Minimum 2 parameters required")
    print("1. subject, 2. message")
    sys.exit(2)

scriptname = sys.argv[0]
scriptname = os.path.basename(scriptname)
subject = sys.argv[1]
content = sys.argv[2]
mailoption = "mail"

if len(sys.argv) > 3 :
    mailoption = sys.argv[3]

logfilename=config.get(" default ","LOGDIR") + "/" + scriptname +".log"
# print logfilename
if config.has_option(" default ","EMAIL1") :
    email1=config.get(" default ","EMAIL1")
else:
    email1=""
if config.has_option(" default ","EMAIL2") :
    email2=config.get(" default ","EMAIL2")
else:
    email2=""
now = str(datetime.now())
now = now [:19]

with open(logfilename,"a") as logfile:
    logmsg = now +" Notify: "+ subject + " " + content
    print(logmsg)
    logfile.write( logmsg + "\n")
    destination = list()
    if email1 != "" :
        destination.append(email1)
    if email2 != "" :
        destination.append(email2)
    if len(destination) > 0 \
    and mailoption != "nomail" :
        msg = MIMEText(now + " " + os.uname().nodename + " " + content)
        msg['Subject'] = subject
        msg['From'] = "mythtv <" + config.get(" default ","SMTP_SENDER") + ">"
        msg['To'] = destination[0]
        msg['Date'] = formatdate(localtime=True)
        smtpsrv = smtplib.SMTP_SSL(config.get(" default ","SMTP_HOST"), timeout=30)
        smtpsrv.login(config.get(" default ","SMTP_USER"),privConfig.get(" default ","SMTP_PASSWORD"))
        smtpsrv.sendmail(config.get(" default ","SMTP_SENDER"),destination,msg.as_string())
    if config.has_option(" default ","NTFY_TOPIC") :
        ntfy_topic=config.get(" default ","NTFY_TOPIC")
        msgtext = subject + " " + now + " " + os.uname().nodename + " " + content
        requests.post("https://ntfy.sh/" + ntfy_topic,
            data=msgtext.encode(encoding='utf-8'))

