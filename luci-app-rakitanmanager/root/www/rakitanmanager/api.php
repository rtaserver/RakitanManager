<?php
    include('config.inc.php');

    function json_response($data) {
        $resp = array(
            'status' => 'OK',
            'data' => $data
        );
        header("Content-Type: application/json; charset=UTF-8");
        echo json_encode($resp, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
    }

?>
