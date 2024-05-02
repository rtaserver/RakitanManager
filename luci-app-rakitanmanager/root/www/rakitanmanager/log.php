<?php
$log_file = '/var/log/rakitanmanager.log';
if (!file_exists($log_file)) {
    $log_message = shell_exec("date '+%Y-%m-%d %H:%M:%S'") . " - Belum Ada Log\n";
    file_put_contents($log_file, $log_message, FILE_APPEND);
} else {
    $log_lines = file($log_file);
    foreach ($log_lines as $line) {
        echo nl2br($line);
    }
}
?>