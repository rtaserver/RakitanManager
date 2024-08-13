<?php

// Fungsi untuk membaca data modem dari file JSON
function bacaDataModem()
{
    $file = '/usr/share/rakitanmanager/data-modem.json';
    if (file_exists($file)) {
        $data = file_get_contents($file);
        $decoded_data = json_decode($data, true);
        if (isset($decoded_data['modems'])) {
            return $decoded_data['modems'];
        }
    }
    return [];
}

// Fungsi untuk menyimpan data modem ke file JSON
function simpanDataModem($modems)
{
    $file = '/usr/share/rakitanmanager/data-modem.json';
    $data = json_encode(['modems' => $modems], JSON_PRETTY_PRINT);
    file_put_contents($file, $data);
}

// Periksa apakah ada pengiriman formulir tambah modem
if ($_SERVER["REQUEST_METHOD"] == "POST" && isset($_POST["tambah_modem"])) {
    $modems = bacaDataModem();
    $modems[] = [
        "jenis" => $_POST["jenis"],
        "nama" => $_POST["nama"],
        "cobaping" => $_POST["cobaping"],
        "portmodem" => $_POST["portmodem"],
        "interface" => $_POST["interface"],
        "iporbit" => $_POST["iporbit"],
        "usernameorbit" => $_POST["usernameorbit"],
        "passwordorbit" => $_POST["passwordorbit"],
        "metodeping" => $_POST["metodeping"],
        "hostbug" => $_POST["hostbug"],
        "androidid" => $_POST["androidid"],
        "modpes" => $_POST["modpes"],
        "devicemodem" => $_POST["devicemodem"],
        "delayping" => $_POST["delayping"],
        "script" => $_POST["script"],
        "status" => 0
    ];
    simpanDataModem($modems);
}

// Periksa apakah ada pengiriman formulir edit modem
if ($_SERVER["REQUEST_METHOD"] == "POST" && isset($_POST["edit_modem"])) {
    $index = $_POST["index"];
    $modems = bacaDataModem();
    if (isset($modems[$index])) {
        $modems[$index]["jenis"] = $_POST["edit_jenis"];
        $modems[$index]["nama"] = $_POST["edit_nama"];
        $modems[$index]["cobaping"] = $_POST["edit_cobaping"];
        $modems[$index]["portmodem"] = $_POST["edit_portmodem"];
        $modems[$index]["interface"] = $_POST["edit_interface"];
        $modems[$index]["iporbit"] = $_POST["edit_iporbit"];
        $modems[$index]["usernameorbit"] = $_POST["edit_usernameorbit"];
        $modems[$index]["passwordorbit"] = $_POST["edit_passwordorbit"];
        $modems[$index]["metodeping"] = $_POST["edit_metodeping"];
        $modems[$index]["hostbug"] = $_POST["edit_hostbug"];
        $modems[$index]["androidid"] = $_POST["edit_androidid"];
        $modems[$index]["modpes"] = $_POST["edit_modpes"];
        $modems[$index]["devicemodem"] = $_POST["edit_devicemodem"];
        $modems[$index]["delayping"] = $_POST["edit_delayping"];
        $modems[$index]["script"] = $_POST["edit_script"];
        simpanDataModem($modems);
    }
}


// Periksa apakah ada permintaan update status
if ($_SERVER["REQUEST_METHOD"] == "GET" && isset($_GET["update_status"])) {
    $index = $_GET["update_status"];
    $modems = bacaDataModem();
    if (isset($modems[$index])) {
        if (isset($_GET["status"])) {
            // Set status from $_POST parameter
            $modems[$index]["status"] = (int) $_GET["status"];
        } else {
            // Toggle between 0 (enabled) and -1 (disabled)
            $modems[$index]["status"] = ($modems[$index]["status"] ?? 0) == 0 ? -1 : 0;
        }

        $modems = array_values($modems); // Re-index array to avoid gaps
        simpanDataModem($modems);
    }

    header("Location: " . $_SERVER['PHP_SELF']);
    exit;
}

// Periksa apakah ada permintaan penghapusan modem
if ($_SERVER["REQUEST_METHOD"] == "GET" && isset($_GET["hapus_modem"])) {
    $index = $_GET["hapus_modem"];
    $modems = bacaDataModem();
    if (isset($modems[$index])) {
        unset($modems[$index]);
        $modems = array_values($modems); // Re-index array to avoid gaps
        simpanDataModem($modems);
    }
}

// Baca data modem
$modems = bacaDataModem();
$modem_count = count($modems); // Hitung jumlah modem yang tersimpan

// Periksa apakah ada modem yang tersimpan
if ($modem_count == 0) {
    $start_button_disabled = 'disabled'; // Nonaktifkan tombol jika tidak ada modem yang tersimpan
} else {
    $start_button_disabled = ''; // Aktifkan tombol jika ada modem yang tersimpan
}

if (isset($_POST['enable'])) {
    $log_message = shell_exec("date '+%Y-%m-%d %H:%M:%S'") . " - Script Telah Di Aktifkan\n";
    file_put_contents('/var/log/rakitanmanager.log', $log_message, FILE_APPEND);
    shell_exec('/usr/share/rakitanmanager/core-manager.sh -s');
    exec("uci set rakitanmanager.cfg.enabled='1' && uci commit rakitanmanager");
} elseif (isset($_POST['disable'])) {
    $log_message = shell_exec("date '+%Y-%m-%d %H:%M:%S'") . " - Script Telah Di Berhentikan\n";
    file_put_contents('/var/log/rakitanmanager.log', $log_message, FILE_APPEND);
    shell_exec('/usr/share/rakitanmanager/core-manager.sh -k');
    exec("uci set rakitanmanager.cfg.enabled='0' && uci commit rakitanmanager");
}


$contnetwork = file_get_contents('/etc/config/network'); // Membaca isi file
$linesnetwork = explode("\n", $contnetwork); // Memisahkan setiap baris

$interface_modem = [];
foreach ($linesnetwork as $linenetwork) {
    if (strpos($linenetwork, 'config interface') !== false) {
        // Menemukan baris yang berisi 'config interface'
        $parts = explode(' ', $linenetwork);
        $interface = trim(end($parts), "'"); // Menghapus tanda petik
        $interface_modem[] = $interface; // Menambahkan nama interface ke array
    }
}

$interfaces = []; // Inisialisasi array interface
$outputinterface = shell_exec('ip address');
preg_match_all('/^\d+: (\S+):/m', $outputinterface, $matchesinterface);
if (!empty($matchesinterface[1])) {
    // Mengonversi daftar interface menjadi array asosiatif untuk diproses lebih lanjut
    $getinterface = array_combine($matchesinterface[1], $matchesinterface[1]);
    $interfaces = $getinterface; // Memperbarui array interfaces dengan hasil yang baru ditemukan
} else {
    $interfaces = []; // Atur kembali interfaces sebagai array kosong jika tidak ada interface yang ditemukan
}

$androididdevices = shell_exec("adb devices | grep 'device' | grep -v 'List of' | awk {'print $1'}");
$androidid = explode("\n", trim($androididdevices)); // Memisahkan daftar perangkat menjadi array

$rakitanmanager_status = exec("uci -q get rakitanmanager.cfg.enabled") ? 1 : 0;
$branch_select = exec("uci -q get rakitanmanager.cfg.branch");
?>

<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Daftar Modem</title>
    <?php
    include ("head.php");
    exec('chmod -R 755 /usr/share/rakitanmanager/core-manager.sh');
    exec('chmod -R 755 /usr/share/rakitanmanager/modem-hilink.sh');
    exec('chmod -R 755 /usr/share/rakitanmanager/modem-mf90.sh');
    exec('chmod -R 755 /usr/share/rakitanmanager/modem-hp.sh');
    exec('chmod -R 755 /usr/share/rakitanmanager/modem-rakitan.sh');
    exec('chmod -R 755 /usr/share/rakitanmanager/modem-orbit.py');
    ?>
    <script src="lib/vendor/jquery/jquery-3.6.0.slim.min.js"></script>

    <script>
        $(document).ready(function () {
            var previousContent = "";
            setInterval(function () {
                $.get("log.php")
                .done(function (data) {
                    if (data !== previousContent) {
                        previousContent = data;
                        $("#logContent").html(data);
                        var elem = document.getElementById('logContent');
                        elem.scrollTop = elem.scrollHeight;
                    }
                })
                .fail(function(jqXHR, textStatus, errorThrown) {
                    console.error("Gagal mengambil log: " + textStatus, errorThrown);
                });
            }, 1000);

            // Fungsi untuk memeriksa koneksi internet
            function checkConnection() {
                return navigator.onLine;
            }

            // Fungsi untuk memeriksa pembaruan dari GitHub API
            function checkUpdate() {
                if (!checkConnection()) {
                    // Jika tidak ada koneksi, hentikan proses
                    return;
                }

                <?php if ($branch_select == "main"): ?>
                    var latestVersionUrl = 'https://raw.githubusercontent.com/rtaserver/RakitanManager/package/main/version';
                    var changelogUrl = 'https://raw.githubusercontent.com/rtaserver/RakitanManager/package/main/changelog.txt';
                <?php endif; ?>
                <?php if ($branch_select == "dev"): ?>
                    var latestVersionUrl = 'https://raw.githubusercontent.com/rtaserver/RakitanManager/package/dev/version';
                    var changelogUrl = 'https://raw.githubusercontent.com/rtaserver/RakitanManager/package/dev/changelog.txt';
                <?php endif; ?>

                fetch(latestVersionUrl)
                    .then(response => {
                        if (!response.ok) {
                            throw new Error('Network response was not ok');
                        }
                        return response.text();
                    })
                    .then(data => {
                        <?php if ($branch_select == "main"): ?>
                            var latestVersion = data.split('\n')[0].trim().toLowerCase();
                            var currentVersion = '<?php echo trim(file_get_contents("versionmain.txt")); ?>';

                            // Periksa jika versi terbaru berbeda dari versi saat ini
                            if (latestVersion && latestVersion !== currentVersion) {
                                // Tampilkan modal
                                $('#updateModal').modal('show');

                                // Load Changelog
                                $.get(changelogUrl, function (changelogData) {
                                    // Find the version in Changelog
                                    var versionIndex = changelogData.indexOf('**Changelog**');
                                    if (versionIndex !== -1) {
                                        // Get Changelog entries starting from the found version
                                        var changelog = changelogData.substring(versionIndex);
                                        // Replace special characters
                                        changelog = changelog.replace(/%0A/g, '\n'); // Replace '%0A' with '\n' (newline)
                                        changelog = changelog.replace(/%0D/g, ''); // Remove '%0D' (carriage return)
                                        $('#changelogContent').html(changelog);
                                    } else {
                                        $('#changelogContent').html('Changelog Tidak Tersedia');
                                    }
                                });
                            }
                        <?php endif; ?>
                        <?php if ($branch_select == "dev"): ?>
                            var latestVersion = data.split('\n')[0].trim().toLowerCase();
                            var currentVersion = '<?php echo trim(file_get_contents("versiondev.txt")); ?>';

                            // Periksa jika versi terbaru berbeda dari versi saat ini
                            if (latestVersion && latestVersion !== currentVersion) {
                                // Tampilkan modal
                                $('#updateModal').modal('show');

                                // Load Changelog
                                $.get(changelogUrl, function (changelogData) {
                                    // Find the version in Changelog
                                    var versionIndex = changelogData.indexOf('**Changelog**');
                                    if (versionIndex !== -1) {
                                        // Get Changelog entries starting from the found version
                                        var changelog = changelogData.substring(versionIndex);
                                        // Replace special characters
                                        changelog = changelog.replace(/%0A/g, '\n'); // Replace '%0A' with '\n' (newline)
                                        changelog = changelog.replace(/%0D/g, ''); // Remove '%0D' (carriage return)
                                        $('#changelogContent').html(changelog);
                                    } else {
                                        $('#changelogContent').html('Changelog Tidak Tersedia');
                                    }
                                });
                            }
                        <?php endif; ?>
                    })
                    .catch(error => {
                        // Jika koneksi gagal atau ada kesalahan lain dalam memeriksa pembaruan
                        console.error('Failed to check for update:', error);
                    });
            }

            // Panggil fungsi untuk memeriksa pembaruan ketika dokumen selesai dimuat
            checkUpdate();
        });
    </script>

</head>
<div class="modal fade" id="updateModal" tabindex="-1" role="dialog" aria-labelledby="updateModalLabel"
    aria-hidden="true">
    <div class="modal-dialog" role="document">
        <div class="modal-content">
            <div class="modal-header">
                <?php if ($branch_select == "main"): ?>
                    <h5 class="modal-title" id="updateModalLabel">Update Available | Branch Main</h5>
                <?php endif; ?>
                <?php if ($branch_select == "dev"): ?>
                    <h5 class="modal-title" id="updateModalLabel">Update Available | Branch Dev</h5>
                <?php endif; ?>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                    <span aria-hidden="true">&times;</span>
                </button>
            </div>
            <div class="modal-body">
                <h5>Changelog:</h5>
                <pre id="changelogContent"></pre>
                <p>Update Dengan Bash Script :&nbsp;</p>
                <div class="highlight highlight-source-shell notranslate position-relative overflow-auto" dir="auto">
                    <pre><span class="pl-c"><span class="pl-c">#</span> Copy Script Di Bawah Dan Paste Di Terminal</span>
bash -c <span class="pl-s"><span class="pl-pds">&quot;</span><span class="pl-s"><span class="pl-pds">$(</span>wget -qO - <span class="pl-s"><span class="pl-pds">&apos;</span>https://raw.githubusercontent.com/rtaserver/RakitanManager/dev/install.sh<span class="pl-pds">&apos;</span></span><span class="pl-pds">)</span></span><span class="pl-pds">&quot;</span></span></pre>
                </div>
            </div>
            <div class="modal-footer">
                <?php if ($branch_select == "main"): ?>
                    <a href="https://github.com/rtaserver/RakitanManager/blob/main/CHANGELOG.md" target="_blank"
                        class="btn btn-primary">Full Changelog</a>
                    <a href="https://github.com/rtaserver/RakitanManager/tree/package/main" target="_blank"
                        class="btn btn-primary">Download Dan Update</a>
                <?php endif; ?>
                <?php if ($branch_select == "dev"): ?>
                    <a href="https://github.com/rtaserver/RakitanManager/blob/dev/CHANGELOG.md" target="_blank"
                        class="btn btn-primary">Full Changelog</a>
                    <a href="https://github.com/rtaserver/RakitanManager/tree/package/dev" target="_blank"
                        class="btn btn-primary">Download Dan Update</a>
                <?php endif; ?>
                <button type="button" class="btn btn-secondary" data-dismiss="modal">Close</button>
            </div>
        </div>
    </div>
</div>

<?php
    $file_path = 'modal_status.txt';
    $show_modal = true;

    // Periksa apakah file ada dan baca statusnya
    if (file_exists($file_path)) {
        $file_content = file_get_contents($file_path);
        $status_data = json_decode($file_content, true);
        $last_shown_date = $status_data['last_shown_date'] ?? '';
        
        if ($last_shown_date == date('Y-m-d')) {
            $show_modal = false;
        }
    }

    // Set status jika checkbox dicentang dan form disubmit
    if ($_SERVER['REQUEST_METHOD'] == 'POST') {
        if (isset($_POST['dont_show'])) {
            $status_data = ['last_shown_date' => date('Y-m-d')];
            file_put_contents($file_path, json_encode($status_data));
            $show_modal = false;
        } else {
            $status_data = ['last_shown_date' => date('Y-m-d')];
            file_put_contents($file_path, json_encode($status_data));
            $show_modal = false;
        }
    }
?>

<div class="modal fade" id="myModal" tabindex="-1" aria-labelledby="exampleModalLabel" aria-hidden="true">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title" id="exampleModalLabel">Ads / Donate Me :)</h5>
                <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                    <span aria-hidden="true">&times;</span>
                </button>
            </div>
            <div class="modal-body">
                <form method="post" id="modalForm">
                    <div class="text-center">
                        <img src="./img/saweria.png" alt="Donate">
                    </div>
                    <br>
                    <div class="form-check">
                        <input type="checkbox" class="form-check-input" id="dontShow" name="dont_show">
                        <label class="form-check-label" for="dontShow">Jangan tampilkan lagi hari ini</label>
                    </div>
                    <a href="https://saweria.co/rizkikotet" target="_blank" class="btn btn-primary">Saweria</a>
                    <button type="submit" class="btn btn-primary" id="okButton" disabled>OK</button>
                    <button type="button" class="btn btn-secondary" data-dismiss="modal">Close</button>
                </form>
            </div>
        </div>
    </div>
</div>

<body>
    <div id="app">
        <?php include ('navbar.php'); ?>
        <form id="myForm" method="POST" class="mt-5">
            <div class="container-fluid">
                <div class="row py-2">
                    <div class="col-lg-8 col-md-9 mx-auto mt-3">
                        <div class="card">
                            <div class="card-header">
                                <div class="text-center">
                                    <h4><i class="fa fa-home"></i> RAKITAN MANAGER</h4>
                                </div>
                            </div>
                            <div class="card-body">
                                <div class="card-body py-0 px-0">
                                    <div class="body">
                                        <div class="text-center">
                                            <img src="curent.svg" alt="Current Version">
                                            <img alt="Latest Version"
                                                src="https://img.shields.io/github/v/release/rtaserver/RakitanManager?display_name=tag&logo=openwrt&label=Latest%20Version&color=dark-green">
                                        </div>
                                        <br>
                                    </div>
                                    <div class="container-fluid">
                                        <div class="container mt-5">

                                            <div class="container">
                                                <div class="row">
                                                    <div class="col-md-6">
                                                        <button type="button" class="btn btn-primary btn-block mb-3"
                                                            data-toggle="modal" data-target="#tambahModemModal" <?php if ($rakitanmanager_status == 1)
                                                                echo 'disabled'; ?>>Tambah Modem</button>
                                                    </div>
                                                    <div class="col-md-6">
                                                        <form method="POST">
                                                            <?php if ($rakitanmanager_status == 1): ?>
                                                                <button type="submit" class="btn btn-danger btn-block mb-3"
                                                                    name="disable">Stop Modem</button>
                                                            <?php else: ?>
                                                                <button type="submit" class="btn btn-success btn-block mb-3"
                                                                    name="enable" <?php echo $start_button_disabled; ?>>Start Modem</button>
                                                            <?php endif; ?>
                                                        </form>
                                                    </div>
                                                </div>
                                            </div>
                                            <table class="table">
                                                <thead>
                                                    <tr>
                                                        <th scope="col">Nama</th>
                                                        <th scope="col">Jenis Modem</th>
                                                        <th scope="col">Metode</th>
                                                        <th scope="col">Host</th>
                                                        <th scope="col">Action</th>
                                                    </tr>
                                                </thead>
                                                <tbody>
                                                     <?php 
                                                        foreach ($modems as $index => $modem):
                                                            $status = match($modem["status"] ?? null) {
                                                                -1 => 'bg-secondary text-white', // disabled
                                                                // 1 => 'bg-primary', // connected
                                                                2 => 'bg-warning', // disconnected
                                                                default => '',        // Default, no class
                                                            };
                                                            
                                                        ?>
                                                        <tr class="<?= $status ?>">
                                                            <td><?= $modem["nama"] ?></td>
                                                            <td><?= $modem["jenis"] ?></td>
                                                            <td><?= $modem["metodeping"] ?></td>
                                                            <td><?= $modem["hostbug"] ?></td>
                                                            <td>
                                                                <button type="button" class="btn btn-dark btn-sm" 
                                                                    onclick="updateStatus(<?= $index ?>)" <?php if ($rakitanmanager_status == 1)
                                                                          echo 'disabled'; ?>>
                                                                    <i class="fa <?= ($modem['status'] ?? 0) ? 'fa-ban' : 'fa-check' ?>"></i>
                                                                </button>
                                                                <button type="button" class="btn btn-primary btn-sm"
                                                                    onclick="editModem(<?= $index ?>)" <?php if ($rakitanmanager_status == 1)
                                                                          echo 'disabled'; ?>><i class="fa fa-pencil"></i></button>
                                                                <button type="button" class="btn btn-danger btn-sm"
                                                                    onclick="hapusModem(<?= $index ?>)" <?php if ($rakitanmanager_status == 1)
                                                                          echo 'disabled'; ?>><i class="fa fa-trash"></i></button>
                                                            </td>
                                                        </tr>
                                                    <?php endforeach; ?>
                                                </tbody>
                                            </table>
                                            <form method="POST" class="mt-5">
                                                <div class="row">
                                                    <div class="col pt-2">
                                                        <pre id="logContent" class="form-control text-left"
                                                            style="height: 200px; width: auto; font-size:80%; background-image-position: center; background-color: #f8f9fa "></pre>
                                                    </div>
                                                </div>
                                            </form>
                                        </div>

                                        <!-- Modal Tambah Modem -->
                                        <div class="modal fade" id="tambahModemModal" tabindex="-1"
                                            aria-labelledby="tambahModemModalLabel" aria-hidden="true">
                                            <div class="modal-dialog">
                                                <div class="modal-content">
                                                    <div class="modal-header">
                                                        <h5 class="modal-title" id="tambahModemModalLabel">Tambah Modem
                                                        </h5>
                                                        <button type="button" class="close" data-dismiss="modal"
                                                            aria-label="Close">
                                                            <span aria-hidden="true">&times;</span>
                                                        </button>
                                                    </div>
                                                    <form id="tambahModemForm" onsubmit="return validateFormTambah()"
                                                        method="post">
                                                        <div class="modal-body">
                                                            <div class="form-group">
                                                                <label for="jenis">Jenis Modem:</label><br>
                                                                <select name="jenis" id="jenis"
                                                                    class="form-control">
                                                                    <option value="rakitan">Modem Rakitan</option>
                                                                    <option value="hp">Modem HP</option>
                                                                    <option value="orbit">Modem Huawei / Orbit</option>
                                                                    <option value="hilink">Modem Hilink</option>
                                                                    <option value="mf90">Modem mf90</option>
                                                                    <option value="customscript">Custom Script</option>
                                                                </select>
                                                            </div>
                                                            <div class="form-group">
                                                                <label for="nama">Nama Modem:</label>
                                                                <input type="text" id="nama" name="nama"
                                                                    class="form-control" placeholder="Nama Bebas">
                                                            </div>
                                                            <div class="form-group" id="rakitan_field">
                                                                <label for="portmodem">Pilih Port Modem:</label>
                                                                <select name="portmodem" id="portmodem"
                                                                    class="form-control">
                                                                    <option value="/dev/ttyUSB0">/dev/ttyUSB0</option>
                                                                    <option value="/dev/ttyUSB1">/dev/ttyUSB1</option>
                                                                    <option value="/dev/ttyUSB2">/dev/ttyUSB2</option>
                                                                    <option value="/dev/ttyUSB3">/dev/ttyUSB3</option>
                                                                    <option value="/dev/ttyUSB4">/dev/ttyUSB4</option>
                                                                    <option value="/dev/ttyUSB5">/dev/ttyUSB5</option>
                                                                    <option value="/dev/ttyUSB6">/dev/ttyUSB6</option>
                                                                    <option value="/dev/ttyUSB7">/dev/ttyUSB7</option>
                                                                    <option value="/dev/ttyACM0">/dev/ttyACM0</option>
                                                                    <option value="/dev/ttyACM1">/dev/ttyACM1</option>
                                                                    <option value="/dev/ttyACM2">/dev/ttyACM2</option>
                                                                    <option value="/dev/ttyACM3">/dev/ttyACM3</option>
                                                                    <option value="/dev/ttyACM4">/dev/ttyACM4</option>
                                                                    <option value="/dev/ttyACM5">/dev/ttyACM5</option>
                                                                    <option value="/dev/ttyACM6">/dev/ttyACM6</option>
                                                                    <option value="/dev/ttyACM7">/dev/ttyACM7</option>
                                                                </select>
                                                                <label for="interface">Interface Modem Manager:</label>
                                                                <select name="interface" id="interface"
                                                                    class="form-control">
                                                                    <?php
                                                                    foreach ($interface_modem as $interface) {
                                                                        echo "<option value=\"$interface\"";
                                                                        echo ">$interface</option>";
                                                                    }
                                                                    ?>
                                                                </select>
                                                            </div>
                                                            <div class="form-group" id="orbit_field">
                                                                <label for="iporbit">IP Modem:</label>
                                                                <input type="text" id="iporbit" name="iporbit"
                                                                    class="form-control" placeholder="192.168.8.1"
                                                                    value="192.168.8.1">
                                                                <label for="usernameorbit">Username:</label>
                                                                <input type="text" id="usernameorbit"
                                                                    name="usernameorbit" class="form-control"
                                                                    placeholder="admin" value="admin">
                                                                <label for="passwordorbit">Password:</label>
                                                                <input type="text" id="passwordorbit"
                                                                    name="passwordorbit" class="form-control"
                                                                    placeholder="admin" value="admin">
                                                            </div>
                                                            <div class="form-group" id="hp_field">
                                                                <label for="androidid">Pilih Android Device:</label>
                                                                <select name="androidid" id="androidid"
                                                                    class="form-control">
                                                                    <?php
                                                                    if (empty($androidid)) {
                                                                        echo "<option value=''>Tidak ada Android yang terdeteksi</option>";
                                                                    } else {
                                                                        foreach ($androidid as $android_id) {
                                                                            echo "<option value='$android_id'>$android_id</option>";
                                                                        }
                                                                    }
                                                                    ?>
                                                                </select>
                                                                <label for="modpes">Versi Modpes:</label>
                                                                <select name="modpes" id="modpes"
                                                                    class="form-control">
                                                                    <option value="modpesv1">Mode Pesawat V1</option>
                                                                    <option value="modpesv2">Mode Pesawat V2</option>
                                                                </select>
                                                            </div>
                                                            <div class="form-group" id="customscript_field">
                                                                <label for="script">Custom Script:</label>
                                                                <textarea required type="text" id="script" name="script"
                                                                    class="form-control"
                                                                    placeholder="Custom Script">#!/bin/bash</textarea>
                                                            </div>
                                                            <div class="form-group">
                                                                <label for="metodeping">Pilih Metode PING:</label>
                                                                <select id="metodeping" name="metodeping"
                                                                    class="form-control">
                                                                    <option value="icmp">ICMP</option>
                                                                    <option value="curl">CURL</option>
                                                                    <option value="http">HTTP</option>
                                                                    <option value="https">HTTPS</option>
                                                                </select>
                                                                <label for="hostbug">Host / Bug Untuk Ping | Multi
                                                                    Host:</label>
                                                                <input type="text" id="hostbug" name="hostbug"
                                                                    class="form-control"
                                                                    placeholder="1.1.1.1 8.8.8.8 google.com"
                                                                    value="google.com facebook.com">
                                                                <label for="devicemodem">Device Modem Untuk Cek
                                                                    PING:</label>
                                                                <select name="devicemodem" id="devicemodem"
                                                                    class="form-control">
                                                                    <option value="disabled">Jangan Gunakan | Default</option>
                                                                    <?php
                                                                    foreach ($interfaces as $devicemodem) {
                                                                        echo "<option value=\"$devicemodem\"";
                                                                        echo ">$devicemodem</option>";
                                                                    }
                                                                    ?>
                                                                </select>
                                                                <label for="cobaping">Percobaan Ping Gagal:</label>
                                                                <input type="number" id="cobaping" name="cobaping"
                                                                    class="form-control" placeholder="2"
                                                                    value="2">
                                                                <label for="delayping">Jeda Waktu Detik | Sebelum
                                                                    Melanjutkan Cek PING:</label>
                                                                <input type="number" id="delayping" name="delayping"
                                                                    class="form-control" placeholder="1" value="3">
                                                            </div>
                                                        </div>
                                                        <div class="modal-footer">
                                                            <button type="button" class="btn btn-secondary"
                                                                data-dismiss="modal">Tutup</button>
                                                            <button type="submit" name="tambah_modem"
                                                                class="btn btn-primary">Simpan</button>
                                                        </div>
                                                    </form>
                                                </div>
                                            </div>
                                        </div>

                                        <div class="modal fade" id="editModemModal" tabindex="-1"
                                            aria-labelledby="editModemModalLabel" aria-hidden="true">
                                            <div class="modal-dialog">
                                                <div class="modal-content">
                                                    <div class="modal-header">
                                                        <h5 class="modal-title" id="editModemModalLabel">Edit Modem</h5>
                                                        <button type="button" class="close" data-dismiss="modal"
                                                            aria-label="Close">
                                                            <span aria-hidden="true">&times;</span>
                                                        </button>
                                                    </div>
                                                    <form id="editModemForm" onsubmit="return validateFormEdit()"
                                                        method="post">
                                                        <div class="modal-body">
                                                            <div class="form-group" id="edit_radio">
                                                                <label for="edit_jenis">Jenis Modem:</label><br>
                                                                <select name="edit_jenis" id="edit_jenis"
                                                                    class="form-control">
                                                                    <option value="rakitan">Modem Rakitan</option>
                                                                    <option value="hp">Modem HP</option>
                                                                    <option value="orbit">Modem Huawei / Orbit</option>
                                                                    <option value="hilink">Modem Hilink</option>
                                                                    <option value="mf90">Modem mf90</option>
                                                                    <option value="customscript">Custom Script</option>
                                                                </select>
                                                            </div>
                                                            <div class="form-group">
                                                                <label for="edit_nama">Nama Modem:</label>
                                                                <input type="text" id="edit_nama" name="edit_nama"
                                                                    class="form-control" placeholder="Nama Bebas">
                                                            </div>
                                                            <div class="form-group" id="edit_rakitan_field">
                                                                <label for="edit_portmodem">Pilih Port Modem:</label>
                                                                <select name="edit_portmodem" id="edit_portmodem"
                                                                    class="form-control">
                                                                    <option value="/dev/ttyUSB0">/dev/ttyUSB0</option>
                                                                    <option value="/dev/ttyUSB1">/dev/ttyUSB1</option>
                                                                    <option value="/dev/ttyUSB2">/dev/ttyUSB2</option>
                                                                    <option value="/dev/ttyUSB3">/dev/ttyUSB3</option>
                                                                    <option value="/dev/ttyUSB4">/dev/ttyUSB4</option>
                                                                    <option value="/dev/ttyUSB5">/dev/ttyUSB5</option>
                                                                    <option value="/dev/ttyUSB6">/dev/ttyUSB6</option>
                                                                    <option value="/dev/ttyUSB7">/dev/ttyUSB7</option>
                                                                    <option value="/dev/ttyACM0">/dev/ttyACM0</option>
                                                                    <option value="/dev/ttyACM1">/dev/ttyACM1</option>
                                                                    <option value="/dev/ttyACM2">/dev/ttyACM2</option>
                                                                    <option value="/dev/ttyACM3">/dev/ttyACM3</option>
                                                                    <option value="/dev/ttyACM4">/dev/ttyACM4</option>
                                                                    <option value="/dev/ttyACM5">/dev/ttyACM5</option>
                                                                    <option value="/dev/ttyACM6">/dev/ttyACM6</option>
                                                                    <option value="/dev/ttyACM7">/dev/ttyACM7</option>
                                                                </select>
                                                                <label for="edit_interface">Interface Modem
                                                                    Manager:</label>
                                                                <select name="edit_interface" id="edit_interface"
                                                                    class="form-control">
                                                                    <?php
                                                                    foreach ($interface_modem as $interface) {
                                                                        echo "<option value=\"$interface\"";
                                                                        echo ">$interface</option>";
                                                                    }
                                                                    ?>
                                                                </select>
                                                            </div>
                                                            <div class="form-group" id="edit_orbit_field">
                                                                <label for="edit_iporbit">IP Modem:</label>
                                                                <input type="text" id="edit_iporbit" name="edit_iporbit"
                                                                    class="form-control" placeholder="192.168.8.1">
                                                                <label for="edit_usernameorbit">Username:</label>
                                                                <input type="text" id="edit_usernameorbit"
                                                                    name="edit_usernameorbit" class="form-control"
                                                                    placeholder="admin">
                                                                <label for="edit_passwordorbit">Password:</label>
                                                                <input type="text" id="edit_passwordorbit"
                                                                    name="edit_passwordorbit" class="form-control"
                                                                    placeholder="admin">
                                                            </div>
                                                            <div class="form-group" id="edit_hp_field">
                                                                <label for="edit_androidid">Pilih Android
                                                                    Device:</label>
                                                                <select name="edit_androidid" id="edit_androidid"
                                                                    class="form-control">
                                                                    <?php
                                                                    if (empty($androidid)) {
                                                                        echo "<option value=''>Tidak ada Android yang terdeteksi</option>";
                                                                    } else {
                                                                        foreach ($androidid as $android_id) {
                                                                            echo "<option value='$android_id'>$android_id</option>";
                                                                        }
                                                                    }
                                                                    ?>
                                                                </select>
                                                                <label for="edit_modpes">Versi Modpes:</label>
                                                                <select name="edit_modpes" id="edit_modpes"
                                                                    class="form-control">
                                                                    <option value="modpesv1">Mode Pesawat V1</option>
                                                                    <option value="modpesv2">Mode Pesawat V2</option>
                                                                </select>
                                                            </div>
                                                            <div class="form-group" id="edit_customscript_field">
                                                                <label for="edit_script">Custom Script:</label>
                                                                <textarea required type="text" id="edit_script" name="edit_script"
                                                                    class="form-control"
                                                                    placeholder="Custom Script">#!/bin/bash</textarea>
                                                            </div>
                                                            <div class="form-group">
                                                                <label for="edit_metodeping">Pilih Metode PING:</label>
                                                                <select id="edit_metodeping" name="edit_metodeping"
                                                                    class="form-control">
                                                                    <option value="icmp">ICMP</option>
                                                                    <option value="curl">CURL</option>
                                                                    <option value="http">HTTP</option>
                                                                    <option value="https">HTTPS</option>
                                                                </select>
                                                                <label for="edit_hostbug">Host / Bug Untuk Ping | Multi
                                                                    Host:</label>
                                                                <input type="text" id="edit_hostbug" name="edit_hostbug"
                                                                    class="form-control"
                                                                    placeholder="1.1.1.1 8.8.8.8 google.com">
                                                                <label for="edit_devicemodem">Device Modem Untuk Cek
                                                                    PING:</label>
                                                                <select name="edit_devicemodem" id="edit_devicemodem"
                                                                    class="form-control">
                                                                    <option value="disabled">Jangan Gunakan | Default</option>
                                                                    <?php
                                                                    foreach ($interfaces as $devicemodem) {
                                                                        echo "<option value=\"$devicemodem\"";
                                                                        echo ">$devicemodem</option>";
                                                                    }
                                                                    ?>
                                                                </select>
                                                                <label for="edit_cobaping">Percobaan Ping Gagal:</label>
                                                                <input type="number" id="edit_cobaping" name="edit_cobaping"
                                                                    class="form-control" placeholder="2">
                                                                <label for="edit_delayping">Jeda Waktu Detik | Sebelum
                                                                    Melanjutkan Cek PING:</label>
                                                                <input type="number" id="edit_delayping"
                                                                    name="edit_delayping" class="form-control"
                                                                    placeholder="1">
                                                            </div>
                                                        </div>
                                                        <div class="modal-footer">
                                                            <button type="button" class="btn btn-secondary"
                                                                data-dismiss="modal">Tutup</button>
                                                            <button type="submit" name="edit_modem"
                                                                class="btn btn-primary">Simpan</button>
                                                            <input type="hidden" name="index" id="editIndex">
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
                </div>
                <?php include ('footer.php'); ?>
            </div>
        </form>
    </div>
    <?php include ("javascript.php"); ?>
    <?php if ($show_modal): ?>
    <script>
        $(document).ready(function() {
            $('#myModal').modal('show');
        });
    </script>
    <?php endif; ?>

    <script>
        $('#modalForm').on('submit', function(e) {
            if ($('#dontShow').is(':checked')) {
                $('#myModal').modal('hide');
            }
        });
        $('#dontShow').change(function() {
            if ($(this).is(':checked')) {
                $('#okButton').removeAttr('disabled');
            } else {
                $('#okButton').attr('disabled', 'disabled');
            }
        });
    </script>
    <script>
        function editModem(index) {
            var modem = <?= json_encode($modems) ?>[index];
            $('#edit_nama').val(modem.nama);
            $('#edit_cobaping').val(modem.cobaping);
            $('#edit_portmodem').val(modem.portmodem);
            $('#edit_interface').val(modem.interface);
            $('#edit_iporbit').val(modem.iporbit);
            $('#edit_usernameorbit').val(modem.usernameorbit);
            $('#edit_passwordorbit').val(modem.passwordorbit);
            $('#edit_metodeping').val(modem.metodeping);
            $('#edit_hostbug').val(modem.hostbug);
            $('#edit_androidid').val(modem.androidid);
            $('#edit_devicemodem').val(modem.devicemodem);
            $('#edit_modpes').val(modem.modpes);
            $('#edit_delayping').val(modem.delayping);
            $('#edit_script').val(modem.script);
            $('#edit_jenis').val(modem.jenis);
            //$('#edit_jenis').prop("disabled", true);

            if (modem.jenis === 'rakitan') {
                $('#edit_rakitan_field').show();
                $('#edit_orbit_field').hide();
                $('#edit_hp_field').hide();
                $('#edit_customscript_field').hide();
            } else if (modem.jenis === 'orbit') {
                $('#edit_rakitan_field').hide();
                $('#edit_orbit_field').show();
                $('#edit_hp_field').hide();
                $('#edit_customscript_field').hide();
            } else if (modem.jenis === 'hilink') {
                $('#edit_rakitan_field').hide();
                $('#edit_orbit_field').show();
                $('#edit_hp_field').hide();
                $('#edit_customscript_field').hide();
            } else if (modem.jenis === 'mf90') {
                $('#edit_rakitan_field').hide();
                $('#edit_orbit_field').show();
                $('#edit_hp_field').hide();
                $('#edit_customscript_field').hide();
            } else if (modem.jenis === 'hp') {
                $('#edit_rakitan_field').hide();
                $('#edit_orbit_field').hide();
                $('#edit_hp_field').show();
                $('#edit_customscript_field').hide();
            } else if (modem.jenis === 'customscript') {
                $('#edit_rakitan_field').hide();
                $('#edit_orbit_field').hide();
                $('#edit_hp_field').hide();
                $('#edit_customscript_field').show();
            }

            $('#editIndex').val(index);
            $('#editModemModal').modal('show');
        }

        function updateStatus(index) {
            window.location.href = '?update_status=' + index;
        }

        function hapusModem(index) {
            if (confirm('Apakah Anda yakin ingin menghapus modem ini?')) {
                window.location.href = '?hapus_modem=' + index;
            }
        }

        $(document).ready(function () {
            // Sembunyikan semua bidang secara default
            $('#rakitan_field, #orbit_field, #hp_field, #customscript_field').hide();

            // Tampilkan bidang rakitan saat halaman dimuat karena itu default
            $('#rakitan_field').show();

            $('#jenis').change(function () {
                var jenis = $(this).val();
                if (jenis === 'rakitan') {
                    $('#rakitan_field').show();
                    $('#orbit_field').hide();
                    $('#hp_field').hide();
                    $('#customscript_field').hide();
                } else if (jenis === 'hp') {
                    $('#rakitan_field').hide();
                    $('#orbit_field').hide();
                    $('#hp_field').show();
                    $('#customscript_field').hide();
                } else if (jenis === 'orbit') {
                    $('#rakitan_field').hide();
                    $('#orbit_field').show();
                    $('#hp_field').hide();
                    $('#customscript_field').hide();
                } else if (jenis === 'hilink') {
                    $('#rakitan_field').hide();
                    $('#orbit_field').show();
                    $('#hp_field').hide();
                    $('#customscript_field').hide();
                } else if (jenis === 'mf90') {
                    $('#rakitan_field').hide();
                    $('#orbit_field').show();
                    $('#hp_field').hide();
                    $('#customscript_field').hide();
                } else if (jenis === 'customscript') {
                    $('#rakitan_field').hide();
                    $('#orbit_field').hide();
                    $('#hp_field').hide();
                    $('#customscript_field').show();
                }
            });

            // Menampilkan bidang sesuai dengan pilihan combobox yang terpilih saat edit
            $('#edit_jenis').change(function () {
                var jenis = $(this).val();
                if (jenis === 'rakitan') {
                    $('#edit_rakitan_field').show();
                    $('#edit_orbit_field').hide();
                    $('#edit_hp_field').hide();
                    $('#edit_customscript_field').hide();
                } else if (jenis === 'hp') {
                    $('#edit_rakitan_field').hide();
                    $('#edit_orbit_field').hide();
                    $('#edit_hp_field').show();
                    $('#edit_customscript_field').hide();
                } else if (jenis === 'orbit') {
                    $('#edit_rakitan_field').hide();
                    $('#edit_orbit_field').show();
                    $('#edit_hp_field').hide();
                    $('#edit_customscript_field').hide();
                } else if (jenis === 'hilink') {
                    $('#edit_rakitan_field').hide();
                    $('#edit_orbit_field').show();
                    $('#edit_hp_field').hide();
                    $('#edit_customscript_field').hide();
                } else if (jenis === 'mf90') {
                    $('#edit_rakitan_field').hide();
                    $('#edit_orbit_field').show();
                    $('#edit_hp_field').hide();
                    $('#edit_customscript_field').hide();
                } else if (jenis === 'customscript') {
                    $('#edit_rakitan_field').hide();
                    $('#edit_orbit_field').hide();
                    $('#edit_hp_field').hide();
                    $('#edit_customscript_field').show();
                }
            });

            // Tambahkan fungsi untuk mengubah status tombol Mulai dan label Status saat diklik
            var statusBerjalan = false;
            $('#mulaiStopButton').click(function () {
                if (!statusBerjalan) {
                    $(this).text('Berhenti').removeClass('btn-primary').addClass('btn-danger');
                    $('.status-label').text('Berjalan').css('color', 'green');
                    // Nonaktifkan semua tombol Edit dan Hapus
                    $('.btn-primary, .btn-danger').prop('disabled', true);
                } else {
                    $(this).text('Mulai').removeClass('btn-danger').addClass('btn-primary');
                    $('.status-label').text('Berhenti').css('color', 'black');
                    // Aktifkan kembali semua tombol Edit dan Hapus
                    $('.btn-primary, .btn-danger').prop('disabled', false);
                }
                statusBerjalan = !statusBerjalan;
            });
        });

        // Function to validate form fields
        function validateFormTambah() {
            var jenis = document.getElementById("jenis").value;
            var nama = document.getElementById("nama").value.trim();
            var cobaping = document.getElementById("cobaping").value.trim();
            var portmodem = document.getElementById("portmodem").value.trim();
            var interface = document.getElementById("interface").value.trim();
            var iporbit = document.getElementById("iporbit").value.trim();
            var usernameorbit = document.getElementById("usernameorbit").value.trim();
            var passwordorbit = document.getElementById("passwordorbit").value.trim();
            var metodeping = document.getElementById("metodeping").value.trim();
            var hostbug = document.getElementById("hostbug").value.trim();
            var androidid = document.getElementById("androidid").value.trim();
            var devicemodem = document.getElementById("devicemodem").value.trim();
            var modpes = document.getElementById("modpes").value.trim();
            var delayping = document.getElementById("delayping").value.trim();
            var script = document.getElementById("script").value.trim();

            if (jenis === "") {
                alert("Pilih jenis modem!");
                return false;
            }
            if (nama === "") {
                alert("Nama modem harus diisi!");
                return false;
            }
            if (cobaping === "") {
                alert("Percobaan gagal ping harus diisi!");
                return false;
            }
            if (jenis === "orbit") {
                if (iporbit === "" || usernameorbit === "" || passwordorbit === "") {
                    alert("Semua bidang IP Modem, Username, dan Password harus diisi untuk modem!");
                    return false;
                }
            }
            if (hostbug === "") {
                alert("Host / Bug untuk ping harus diisi!");
                return false;
            }
            if (delayping === "") {
                alert("Jeda waktu detik sebelum melanjutkan cek PING harus diisi!");
                return false;
            }
            if (script === "") {
                alert("Custom Script harus diisi!");
                return false;
            }
            return true;
        }

        function validateFormEdit() {
            var jenis = document.getElementById("edit_jenis").value;
            var nama = document.getElementById("edit_nama").value.trim();
            var cobaping = document.getElementById("edit_cobaping").value.trim();
            var portmodem = document.getElementById("edit_portmodem").value.trim();
            var interface = document.getElementById("edit_interface").value.trim();
            var iporbit = document.getElementById("edit_iporbit").value.trim();
            var usernameorbit = document.getElementById("edit_usernameorbit").value.trim();
            var passwordorbit = document.getElementById("edit_passwordorbit").value.trim();
            var metodeping = document.getElementById("edit_metodeping").value.trim();
            var hostbug = document.getElementById("edit_hostbug").value.trim();
            var androidid = document.getElementById("edit_androidid").value.trim();
            var devicemodem = document.getElementById("edit_devicemodem").value.trim();
            var modpes = document.getElementById("edit_modpes").value.trim();
            var delayping = document.getElementById("edit_delayping").value.trim();
            var script = document.getElementById("edit_script").value.trim();

            if (jenis === "") {
                alert("Pilih jenis modem!");
                return false;
            }
            if (nama === "") {
                alert("Nama modem harus diisi!");
                return false;
            }
            if (cobaping === "") {
                alert("Percobaan gagal ping harus diisi!");
                return false;
            }
            if (jenis === "orbit") {
                if (iporbit === "" || usernameorbit === "" || passwordorbit === "") {
                    alert("Semua bidang IP Modem, Username, dan Password harus diisi untuk modem!");
                    return false;
                }
            }
            if (hostbug === "") {
                alert("Host / Bug untuk ping harus diisi!");
                return false;
            }
            if (delayping === "") {
                alert("Jeda waktu detik sebelum melanjutkan cek PING harus diisi!");
                return false;
            }
            if (script === "") {
                alert("Custom Script harus diisi!");
                return false;
            }
            return true;
        }
    </script>
</body>

</html>