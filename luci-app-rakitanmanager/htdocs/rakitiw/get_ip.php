<?php
if (isset($_GET["hostname"])) {
    $hostname = $_GET["hostname"];
    $api_url = "http://ip-api.com/json/$hostname";
    $response = file_get_contents($api_url);
    $data = json_decode($response, true);
    if ($data["status"] == "fail") {
        echo "<p class='text-danger'>Error: " . $data["message"] . "</p>";
    } else {
        echo "<p>IP Address for $hostname: " . $data["query"] . "</p>";
    }
}
?>