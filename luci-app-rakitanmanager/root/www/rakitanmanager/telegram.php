<?php
// Fungsi untuk menyimpan konfigurasi ke dalam berkas
function save_config()
{
    // Simpan pesan kustom ke dalam berkas terpisah
    file_put_contents("bot_message.txt", $_POST['message']);
}

// Fungsi untuk memuat konfigurasi dari berkas
function load_config()
{
    $message_file = "bot_message.txt";

    $config = array();

    // Load pesan kustom dari berkas terpisah
    if (file_exists($message_file)) {
        $custom_message = file_get_contents($message_file);
        $config['custom_message'] = $custom_message;
    }

    return $config;
}

// Memuat konfigurasi saat halaman dimuat
$config = load_config();
$token_id = exec("uci -q get rakitanmanager.telegram.token");
$chat_id = exec("uci -q get rakitanmanager.telegram.chatid");
$custom_message = isset($config['custom_message']) ? $config['custom_message'] : '';

// Memproses form ketika disubmit
if (isset($_POST['rakitanmanager'])) {
    $dt = $_POST['rakitanmanager'];
    if ($dt == 'enable') {
        // Simpan konfigurasi
        $token_id = $_POST['tokenid'];
        $chat_id = $_POST['chatid'];
        $custom_message = $_POST['message'];
        exec("uci set rakitanmanager.telegram.token='$token_id' && uci commit rakitanmanager");
        exec("uci set rakitanmanager.telegram.chatid='$chat_id' && uci commit rakitanmanager");
        save_config();
        // Aktifkan bot Telegram
        exec("uci set rakitanmanager.telegram.enabled='1' && uci commit rakitanmanager");
    } elseif ($dt == 'disable') {
        // Nonaktifkan bot Telegram
        exec("uci set rakitanmanager.telegram.enabled='0' && uci commit rakitanmanager");
    } elseif ($dt == 'test') {
        // Mengirim pesan uji bot Telegram
        exec("/usr/bin/rakitanmanager.sh bot_test");
    } elseif ($dt == 'save') {
        // Simpan konfigurasi tanpa mengaktifkan bot Telegram
        $token_id = $_POST['tokenid'];
        $chat_id = $_POST['chatid'];
        $custom_message = $_POST['message'];
        exec("uci set rakitanmanager.telegram.token='$token_id' && uci commit rakitanmanager");
        exec("uci set rakitanmanager.telegram.chatid='$chat_id' && uci commit rakitanmanager");
        save_config();
    }
}

// Memuat status bot dari berkas konfigurasi
$bot_status = exec("uci -q get rakitanmanager.telegram.enabled") ? 1 : 0;
?>

<!DOCTYPE html>
<html lang="en">

<head>
    <?php
    $title = "Home";
    include ("head.php");
    ?>
    <script src="lib/vendor/jquery/jquery-3.6.0.slim.min.js"></script>
    <style>
        .container {
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100%;
        }

        .center-align {
            text-align: center;
        }

        .form-group {
            margin-bottom: 20px;
        }
    </style>
    <script>
        $(document).ready(function () {
            <?php if ($bot_status == 1): ?>
                $("input[name='tokenid'], input[name='chatid'], textarea[name='message']").prop('disabled', true);
            <?php endif; ?>

            $("button[name='rakitanmanager'][value='test']").click(function () {
                var token_id = $("#tokenid").val().trim();
                var chat_id = $("#chatid").val().trim();

                // Memeriksa apakah kedua bidang sudah terisi
                if (token_id === "" || chat_id === "") {
                    alert("Token ID dan Chat ID harus diisi sebelum melakukan pengujian.");
                    return;
                }

                // Nonaktifkan semua tombol dan input
                $("button[name='rakitanmanager'], input[name='tokenid'], input[name='chatid'], textarea[name='message']").prop('disabled', true);

                $.ajax({
                    type: "POST",
                    url: "telegram.php",
                    data: {
                        rakitanmanager: 'test'
                    },
                    success: function (response) {
                        $("button[name='rakitanmanager'], input[name='tokenid'], input[name='chatid'], textarea[name='message']").prop('disabled', false);
                        alert("Test message sent!");
                    }
                });
            });
        });
    </script>
</head>

<body>
    <div id="app">
        <?php include ('navbar.php'); ?>
        <div class="container-fluid">
            <div class="row py-2">
                <div class="col-lg-8 col-md-9 mx-auto mt-3">
                    <div class="card">
                        <div class="card-header">
                            <div class="text-center">
                                <h4><i class="fa fa-telegram"></i> BOT TELEGRAM NOTIF</h4>
                            </div>
                        </div>
                        <div class="card-body">
                            <div class="card-body py-0 px-0">
                                <div class="body">
                                    <div class="text-center">
                                        <img src="curent.svg" alt="Curent Version">
                                        <img alt="Latest Version"
                                            src="https://img.shields.io/github/v/release/rtaserver/RakitanManager?display_name=tag&logo=openwrt&label=Latest%20Version&color=dark-green">
                                    </div>
                                    <br>
                                    <p style="text-align: center;"><strong>Ini Hanya Untuk Notifikasi BOT Jika IP
                                            Berubah Internet Kembali Aktif</strong></p>
                                </div>
                                <div class="container-fluid">
                                    <div class="row">
                                        <div class="col-md-8 mx-auto">
                                            <form action="telegram.php" method="post">
                                                <div class="form-group">
                                                    <label for="tokenid">Token ID Bot Telegram</label>
                                                    <input required type="text" id="tokenid" name="tokenid"
                                                        class="form-control" placeholder="Token ID"
                                                        value="<?php echo $token_id; ?>">
                                                </div>
                                                <div class="form-group">
                                                    <label for="chatid">Chat / Group ID Telegram</label>
                                                    <input required type="text" id="chatid" name="chatid"
                                                        class="form-control" placeholder="Chat ID"
                                                        value="<?php echo $chat_id; ?>">
                                                </div>
                                                <div class="form-group">
                                                    <label for="message">Custom Message Telegram</label>
                                                    <textarea required type="text" id="message" name="message"
                                                        class="form-control"
                                                        placeholder="Custom Message"><?php echo $custom_message; ?></textarea>
                                                    <small class="form-text text-muted">Filter Text :<br>
                                                        [IP] = Memunculkan Alamat IP<br>
                                                        [NAMAMODEM] = Memuculkan Nama Modem<br>
                                                        [DEVICE_PROCESSOR] = Memunculkan Nama Processor<br>
                                                        [DEVICE_MODEL] = Memunculkan Nama Model OpenWrt<br>
                                                        [DEVICE_BOARD] = Memunculkan Nama Board OpenWrt
                                                    </small>
                                                </div>
                                                <div class="form-group d-grid gap-2">
                                                    <?php if ($bot_status == 1): ?>
                                                        <button type="submit" name="rakitanmanager" value="disable"
                                                            class="btn btn-danger">Disable Startup</button>
                                                    <?php else: ?>
                                                        <button type="submit" name="rakitanmanager" value="enable"
                                                            class="btn btn-success">Enable Bot Telegram</button>
                                                        <button type="button" name="rakitanmanager" value="test"
                                                            class="btn btn-info">Test Bot Telegram</button>
                                                        <button type="submit" name="rakitanmanager" value="save"
                                                            class="btn btn-primary">Simpan</button>
                                                    <?php endif; ?>
                                                </div>
                                            </form>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            <?php include ('footer.php'); ?>
        </div>
    </div>
    <?php include ("javascript.php"); ?>
</body>

</html>