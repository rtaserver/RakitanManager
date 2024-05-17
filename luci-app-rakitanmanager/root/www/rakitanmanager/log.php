<?php
$log_file = '/var/log/rakitanmanager.log';

// Periksa apakah file log ada
if (!file_exists($log_file)) {
    // Jika tidak ada, buat file log dan tambahkan pesan
    $log_message = date('Y-m-d H:i:s') . " - Belum Ada Log\n";
    file_put_contents($log_file, $log_message);
} 

// Baca dan tampilkan isi file log jika ada
$log_content = file_get_contents($log_file);
echo nl2br($log_content);
?>