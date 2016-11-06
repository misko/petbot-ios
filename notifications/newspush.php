<?php

// Put your device token here (without spaces):
//$deviceToken = 'ad648e26c765d78bad945eaf7eed7b192ffe6ed47fbfcfe973a11e7ed96931f2';
#$deviceToken = 'e0689bafc4bbf24ab2d199dab7fa7501c05f6d306088dd589a0d0bce8a7585e7';
$deviceToken = '6c543458af05eef72131dffc77c69fc43cc82bc5953447f151c3784737ec96f8';

// Put your private key's passphrase here:
//$passphrase = 'i823blueberries';
$passphrase = '';

$message = $argv[1];
$url = $argv[2];

if (!$message || !$url)
    exit('Example Usage: $php newspush.php \'Breaking News!\' \'https://raywenderlich.com\'' . "\n");

////////////////////////////////////////////////////////////////////////////////

$ctx = stream_context_create();
stream_context_set_option($ctx, 'ssl', 'local_cert', '../certs/push_dev.pem');
stream_context_set_option($ctx, 'ssl', 'passphrase', $passphrase);

// Open a connection to the APNS server
$fp = stream_socket_client(
  'ssl://gateway.sandbox.push.apple.com:2195', $err,
  $errstr, 60, STREAM_CLIENT_CONNECT|STREAM_CLIENT_PERSISTENT, $ctx);

if (!$fp)
  exit("Failed to connect: $err $errstr" . PHP_EOL);

echo 'Connected to APNS' . PHP_EOL;

// Create the payload body
$body['aps'] = array(
  'alert' => array( 
	'title' => $message,
	'body' => 'body',
	),
  'sound' => 'default',
  'mutable-content' => 1,
  );
$body['mediaUrl']="https://petbot.ca:5000/static/selfie.mov";
$body['mediaType']="video";
//$body['mediaUrl']="https://upload.wikimedia.org/wikipedia/commons/d/db/Patern_test.jpg";
//$body['mediaType']="image";

// Encode the payload as JSON
$payload = json_encode($body);
echo $payload;

// Build the binary notification
$msg = chr(0) . pack('n', 32) . pack('H*', $deviceToken) . pack('n', strlen($payload)) . $payload;
// Send it to the server
$result = fwrite($fp, $msg, strlen($msg));
echo "RESULT IS $result";

if (!$result)
  echo 'Message not delivered' . PHP_EOL;
else
  echo 'Message successfully delivered' . PHP_EOL;

// Close the connection to the server
fclose($fp);
