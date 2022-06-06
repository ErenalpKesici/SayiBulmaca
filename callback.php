<?php
header('Content-Type: application/json');

$signed_request = $POST['signed_request'];
$data = parse_signed_request($signed_request);

$app_id = $data['app_id'];
$sender_app_scoped_id = $data['source_id'];
$receiver_app_scoped_ids = $data['target_id'];

// Do something with the data received to trigger a friend request in your Game
// ----

// Note: there is no need to respond with anything specific
// but you can use this to debug it on the
// developer settings panel.
$response = array(
 'app_id' => $app_id,
   'friend_requests_sent' => $receiver_app_scoped_ids,
);

echo json_encode($data);

// -------------------
// utility functions
// --------------------
function parse_signed_request($signed_request) {
 list($encoded_sig, $payload) = explode('.', $signed_request, 2);

 $secret = "2cebc58c46eae8663fa0319bb2bd44f3"; // Use your app secret here

 // decode the data
 $sig = base64_url_decode($encoded_sig);
 $data = json_decode(base64_url_decode($payload), true);

 // confirm the signature
 $expected_sig = hash_hmac('sha256', $payload, $secret, $raw = true);
 if ($sig !== $expected_sig) {
   error_log('Bad Signed JSON signature!');
   return null;
 }

 return $data;
}

function base64_url_decode($input) {
 return base64_decode(strtr($input, '-_', '+/'));
}
?>