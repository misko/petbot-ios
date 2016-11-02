#!/usr/bin/env python
import ssl
import json
import socket
import struct
import binascii


def send_push_message(token, payload):
  # the certificate file generated from Provisioning Portal
  certfile = '../certs/push_dev.pem'
  # APNS server address (use 'gateway.push.apple.com' for production server)
  apns_address = ('gateway.sandbox.push.apple.com', 2195)
  # create socket and connect to APNS server using SSL
  s = socket.socket()
  sock = ssl.wrap_socket(s, ssl_version=ssl.PROTOCOL_SSLv23, certfile=certfile)
  sock.connect(apns_address)
  # generate APNS notification packet
  token = binascii.unhexlify(token)
  fmt = "!cH32sH{0:d}s".format(len(payload))
  cmd = '\x00'
  msg = struct.pack(fmt, cmd, len(token), token, len(payload), payload)
  print sock.write(msg)
  sock.close()
 
if __name__ == '__main__':
  title = "the title"
  body = "body"
  url = "https://petbot.ca:5000/static/selfie.mov"
  payload = {"aps": {"alert" : { "title" : title, "body" : body }, "sound" : "default", "mutable-content" :1 } , "mediaUrl": url, "mediaType" : "video"}
  deviceID="6c543458af05eef72131dffc77c69fc43cc82bc5953447f151c3784737ec96f8"
  send_push_message(deviceID, json.dumps(payload))
