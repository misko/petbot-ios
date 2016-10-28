<?
$apnsHost = 'gateway.sandbox.push.apple.com';
#$apnsCert = 'apns-dev.pem';
$apnsCert = '../certs/push_dev.pem';
$apnsPort = 2195;
$token = 'e0689bafc4bbf24ab2d199dab7fa7501c05f6d306088dd589a0d0bce8a7585e7';
$streamContext = stream_context_create();
stream_context_set_option($streamContext, 'ssl', 'local_cert', $apnsCert);

$apns = stream_socket_client('ssl://' . $apnsHost . ':' . $apnsPort, $error, $errorString, 2, STREAM_CLIENT_CONNECT, $streamContext);

if (!$apns) {
	echo "hey this failed";
}

$payload['aps'] = array('alert' => 'Oh hai!', 'badge' => 1, 'sound' => 'default');
$output = json_encode($payload);
$token = pack('H*', str_replace(' ', '', $token));
echo "test";
echo $apns;
$apnsMessage = chr(0) . chr(0) . chr(32) . $token . chr(0) . chr(strlen($output)) . $output;
echo $apnsMessage;
fwrite($apns, $apnsMessage);

socket_close($apns);
fclose($apns);
?>
