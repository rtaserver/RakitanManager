<?php
// Start session for CSRF protection
session_start();

// Generate CSRF token if not exists
if (empty($_SESSION['csrf_token'])) {
    $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
}

// CSRF Token Verification Function
function verifyCsrfToken($token) {
    return isset($_SESSION['csrf_token']) && hash_equals($_SESSION['csrf_token'], $token);
}

// Fungsi untuk membaca data modem dari file JSON
function bacaDataModem() {
    $file = '/usr/share/rakitanmanager/data-modem.json';
    if (!file_exists($file)) {
        return [];
    }
    
    $data = @file_get_contents($file);
    if ($data === false) {
        error_log("Failed to read modem data file");
        return [];
    }
    
    $decoded_data = json_decode($data, true);
    if (json_last_error() !== JSON_ERROR_NONE) {
        error_log("JSON decode error: " . json_last_error_msg());
        return [];
    }
    
    return isset($decoded_data['modems']) && is_array($decoded_data['modems']) ? $decoded_data['modems'] : [];
}

// Fungsi untuk menyimpan data modem ke file JSON
function simpanDataModem($modems) {
    if (!is_array($modems)) {
        error_log("Invalid modems data type");
        return false;
    }
    
    $file = '/usr/share/rakitanmanager/data-modem.json';
    $data = json_encode(['modems' => $modems], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
    
    if ($data === false) {
        error_log("JSON encode error: " . json_last_error_msg());
        return false;
    }
    
    $result = @file_put_contents($file, $data, LOCK_EX);
    if ($result === false) {
        error_log("Failed to write modem data file");
        return false;
    }
    
    return true;
}

// Input sanitization function
function sanitizeInput($data) {
    if (is_array($data)) {
        return array_map('sanitizeInput', $data);
    }
    return htmlspecialchars(trim($data), ENT_QUOTES, 'UTF-8');
}

// Validate integer input
function validateInteger($value, $min = null, $max = null) {
    if (!is_numeric($value)) {
        return false;
    }
    $intValue = intval($value);
    if ($min !== null && $intValue < $min) {
        return false;
    }
    if ($max !== null && $intValue > $max) {
        return false;
    }
    return $intValue;
}

// Validate modem type
function validateModemType($type) {
    $validTypes = ['rakitan', 'hp', 'orbit', 'hilink', 'mf90', 'customscript'];
    return in_array($type, $validTypes, true) ? $type : null;
}

// Validate ping method
function validatePingMethod($method) {
    $validMethods = ['icmp', 'curl', 'http', 'https'];
    return in_array($method, $validMethods, true) ? $method : null;
}

// Periksa apakah ada pengiriman formulir tambah modem
if ($_SERVER["REQUEST_METHOD"] === "POST" && isset($_POST["tambah_modem"])) {
    if (!verifyCsrfToken($_POST['csrf_token'] ?? '')) {
        die("CSRF token validation failed");
    }
    
    // Validate and sanitize inputs
    $jenis = validateModemType($_POST["jenis"] ?? '');
    $nama = sanitizeInput($_POST["nama"] ?? '');
    $cobaping = validateInteger($_POST["cobaping"] ?? 0, 1, 100);
    $metodeping = validatePingMethod($_POST["metodeping"] ?? '');
    $delayping = validateInteger($_POST["delayping"] ?? 1, 1, 3600);
    
    if (!$jenis || !$nama || !$cobaping || !$metodeping || !$delayping) {
        die("Invalid input data");
    }
    
    $modems = bacaDataModem();
    $newModem = [
        "jenis" => $jenis,
        "nama" => $nama,
        "cobaping" => $cobaping,
        "portmodem" => sanitizeInput($_POST["portmodem"] ?? ''),
        "interface" => sanitizeInput($_POST["interface"] ?? ''),
        "iporbit" => filter_var($_POST["iporbit"] ?? '', FILTER_VALIDATE_IP) ?: sanitizeInput($_POST["iporbit"] ?? ''),
        "usernameorbit" => sanitizeInput($_POST["usernameorbit"] ?? ''),
        "passwordorbit" => $_POST["passwordorbit"] ?? '', // Don't htmlspecialchars passwords
        "metodeping" => $metodeping,
        "hostbug" => sanitizeInput($_POST["hostbug"] ?? ''),
        "androidid" => sanitizeInput($_POST["androidid"] ?? ''),
        "modpes" => sanitizeInput($_POST["modpes"] ?? ''),
        "devicemodem" => sanitizeInput($_POST["devicemodem"] ?? ''),
        "delayping" => $delayping,
        "script" => $_POST["script"] ?? '', // Don't sanitize scripts
        "status" => 0
    ];
    
    $modems[] = $newModem;
    simpanDataModem($modems);
    
    // Redirect to prevent form resubmission
    header("Location: " . $_SERVER['PHP_SELF']);
    exit;
}

// Periksa apakah ada pengiriman formulir edit modem
if ($_SERVER["REQUEST_METHOD"] === "POST" && isset($_POST["edit_modem"])) {
    if (!verifyCsrfToken($_POST['csrf_token'] ?? '')) {
        die("CSRF token validation failed");
    }
    
    $index = validateInteger($_POST["index"] ?? -1, 0);
    if ($index === false) {
        die("Invalid index");
    }
    
    $modems = bacaDataModem();
    if (!isset($modems[$index])) {
        die("Modem not found");
    }
    
    // Validate and sanitize inputs
    $jenis = validateModemType($_POST["edit_jenis"] ?? '');
    $nama = sanitizeInput($_POST["edit_nama"] ?? '');
    $cobaping = validateInteger($_POST["edit_cobaping"] ?? 0, 1, 100);
    $metodeping = validatePingMethod($_POST["edit_metodeping"] ?? '');
    $delayping = validateInteger($_POST["edit_delayping"] ?? 1, 1, 3600);
    
    if (!$jenis || !$nama || !$cobaping || !$metodeping || !$delayping) {
        die("Invalid input data");
    }
    
    $modems[$index]["jenis"] = $jenis;
    $modems[$index]["nama"] = $nama;
    $modems[$index]["cobaping"] = $cobaping;
    $modems[$index]["portmodem"] = sanitizeInput($_POST["edit_portmodem"] ?? '');
    $modems[$index]["interface"] = sanitizeInput($_POST["edit_interface"] ?? '');
    $modems[$index]["iporbit"] = filter_var($_POST["edit_iporbit"] ?? '', FILTER_VALIDATE_IP) ?: sanitizeInput($_POST["edit_iporbit"] ?? '');
    $modems[$index]["usernameorbit"] = sanitizeInput($_POST["edit_usernameorbit"] ?? '');
    $modems[$index]["passwordorbit"] = $_POST["edit_passwordorbit"] ?? '';
    $modems[$index]["metodeping"] = $metodeping;
    $modems[$index]["hostbug"] = sanitizeInput($_POST["edit_hostbug"] ?? '');
    $modems[$index]["androidid"] = sanitizeInput($_POST["edit_androidid"] ?? '');
    $modems[$index]["modpes"] = sanitizeInput($_POST["edit_modpes"] ?? '');
    $modems[$index]["devicemodem"] = sanitizeInput($_POST["edit_devicemodem"] ?? '');
    $modems[$index]["delayping"] = $delayping;
    $modems[$index]["script"] = $_POST["edit_script"] ?? '';
    
    simpanDataModem($modems);
    
    // Redirect to prevent form resubmission
    header("Location: " . $_SERVER['PHP_SELF']);
    exit;
}

// Periksa apakah ada permintaan update status
if ($_SERVER["REQUEST_METHOD"] === "GET" && isset($_GET["update_status"])) {
    $index = validateInteger($_GET["update_status"] ?? -1, 0);
    if ($index === false) {
        die("Invalid index");
    }
    
    $modems = bacaDataModem();
    if (!isset($modems[$index])) {
        die("Modem not found");
    }
    
    if (isset($_GET["status"])) {
        $status = validateInteger($_GET["status"] ?? 0, -1, 2);
        if ($status === false) {
            die("Invalid status");
        }
        $modems[$index]["status"] = $status;
    } else {
        // Toggle between 0 (enabled) and -1 (disabled)
        $modems[$index]["status"] = ($modems[$index]["status"] ?? 0) == 0 ? -1 : 0;
    }
    
    simpanDataModem($modems);
    
    header("Location: " . $_SERVER['PHP_SELF']);
    exit;
}

// Periksa apakah ada permintaan penghapusan modem
if ($_SERVER["REQUEST_METHOD"] === "GET" && isset($_GET["hapus_modem"])) {
    $index = validateInteger($_GET["hapus_modem"] ?? -1, 0);
    if ($index === false) {
        die("Invalid index");
    }
    
    $modems = bacaDataModem();
    if (isset($modems[$index])) {
        unset($modems[$index]);
        $modems = array_values($modems); // Re-index array to avoid gaps
        simpanDataModem($modems);
    }
    
    header("Location: " . $_SERVER['PHP_SELF']);
    exit;
}

// Baca data modem
$modems = bacaDataModem();
$modem_count = count($modems);

// Periksa apakah ada modem yang tersimpan
$start_button_disabled = ($modem_count == 0) ? 'disabled' : '';

// Handle enable/disable commands
if ($_SERVER["REQUEST_METHOD"] === "POST") {
    if (!verifyCsrfToken($_POST['csrf_token'] ?? '')) {
        die("CSRF token validation failed");
    }
    
    $log_file = '/var/log/rakitanmanager.log';
    
    if (isset($_POST['enable'])) {
        $log_message = date('Y-m-d H:M:S') . " - Script Telah Di Aktifkan\n";
        @file_put_contents($log_file, $log_message, FILE_APPEND | LOCK_EX);
        exec('/usr/share/rakitanmanager/core-manager.sh -s > /dev/null 2>&1 &');
        exec("uci set rakitanmanager.cfg.enabled='1' && uci commit rakitanmanager 2>&1");
        
        header("Location: " . $_SERVER['PHP_SELF']);
        exit;
    } elseif (isset($_POST['disable'])) {
        $log_message = date('Y-m-d H:M:S') . " - Script Telah Di Berhentikan\n";
        @file_put_contents($log_file, $log_message, FILE_APPEND | LOCK_EX);
        exec('/usr/share/rakitanmanager/core-manager.sh -k 2>&1');
        exec("uci set rakitanmanager.cfg.enabled='0' && uci commit rakitanmanager 2>&1");
        
        header("Location: " . $_SERVER['PHP_SELF']);
        exit;
    }
}

// Get network interfaces
$interface_modem = [];
$network_file = '/etc/config/network';
if (file_exists($network_file)) {
    $contnetwork = @file_get_contents($network_file);
    if ($contnetwork !== false) {
        $linesnetwork = explode("\n", $contnetwork);
        foreach ($linesnetwork as $linenetwork) {
            if (strpos($linenetwork, 'config interface') !== false) {
                $parts = explode(' ', $linenetwork);
                $interface = trim(end($parts), "'\"");
                if (!empty($interface)) {
                    $interface_modem[] = $interface;
                }
            }
        }
    }
}

// Get available interfaces
$interfaces = [];
$outputinterface = @shell_exec('ip address 2>/dev/null');
if ($outputinterface) {
    preg_match_all('/^\d+: (\S+):/m', $outputinterface, $matchesinterface);
    if (!empty($matchesinterface[1])) {
        $interfaces = $matchesinterface[1];
    }
}

// Get Android devices
$androidid = [];
$androididdevices = @shell_exec("adb devices 2>/dev/null | grep 'device' | grep -v 'List of' | awk '{print $1}'");
if ($androididdevices) {
    $androidid = array_filter(explode("\n", trim($androididdevices)));
}

// Get RakitanManager status
$rakitanmanager_status = (int) @exec("uci -q get rakitanmanager.cfg.enabled 2>/dev/null") ?: 0;
$branch_select = @exec("uci -q get rakitanmanager.cfg.branch 2>/dev/null") ?: 'main';

// Set proper permissions
$scripts = [
    '/usr/share/rakitanmanager/core-manager.sh',
    '/usr/share/rakitanmanager/modem-hilink.sh',
    '/usr/share/rakitanmanager/modem-mf90.sh',
    '/usr/share/rakitanmanager/modem-hp.sh',
    '/usr/share/rakitanmanager/modem-rakitan.sh',
    '/usr/share/rakitanmanager/modem-orbit.py'
];

foreach ($scripts as $script) {
    if (file_exists($script)) {
        @chmod($script, 0755);
    }
}

// Modal status handling
$file_path = '/tmp/modal_status.txt';
$show_modal = true;

if (file_exists($file_path)) {
    $file_content = @file_get_contents($file_path);
    if ($file_content !== false) {
        $status_data = json_decode($file_content, true);
        $last_shown_date = $status_data['last_shown_date'] ?? '';
        
        if ($last_shown_date === date('Y-m-d')) {
            $show_modal = false;
        }
    }
}

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['modal_submit'])) {
    $status_data = ['last_shown_date' => date('Y-m-d')];
    @file_put_contents($file_path, json_encode($status_data), LOCK_EX);
    $show_modal = false;
}

// Get version info
$current_version_main = file_exists("versionmain.txt") ? trim(@file_get_contents("versionmain.txt")) : 'unknown';
$current_version_dev = file_exists("versiondev.txt") ? trim(@file_get_contents("versiondev.txt")) : 'unknown';
?>

<!DOCTYPE html>
<html lang="id">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <title>Daftar Modem - RakitanManager</title>
    <?php include("head.php"); ?>
    <script src="lib/vendor/jquery/jquery-3.6.0.slim.min.js"></script>

    <script>
        $(document).ready(function () {
            var previousContent = "";
            
            // Update log with error handling
            function updateLog() {
                $.get("log.php")
                    .done(function (data) {
                        if (data !== previousContent) {
                            previousContent = data;
                            $("#logContent").html(data);
                            var elem = document.getElementById('logContent');
                            if (elem) {
                                elem.scrollTop = elem.scrollHeight;
                            }
                        }
                    })
                    .fail(function(jqXHR, textStatus, errorThrown) {
                        console.error("Gagal mengambil log: " + textStatus, errorThrown);
                    });
            }
            
            // Update log every second
            setInterval(updateLog, 1000);
            
            // Initial log load
            updateLog();

            // Check for updates
            function checkConnection() {
                return navigator.onLine;
            }

            function checkUpdate() {
                if (!checkConnection()) {
                    return;
                }

                <?php if ($branch_select === "main"): ?>
                    var latestVersionUrl = 'https://raw.githubusercontent.com/rtaserver/RakitanManager/package/main/version';
                    var changelogUrl = 'https://raw.githubusercontent.com/rtaserver/RakitanManager/package/main/changelog.txt';
                    var currentVersion = '<?php echo addslashes($current_version_main); ?>';
                <?php else: ?>
                    var latestVersionUrl = 'https://raw.githubusercontent.com/rtaserver/RakitanManager/package/dev/version';
                    var changelogUrl = 'https://raw.githubusercontent.com/rtaserver/RakitanManager/package/dev/changelog.txt';
                    var currentVersion = '<?php echo addslashes($current_version_dev); ?>';
                <?php endif; ?>

                fetch(latestVersionUrl)
                    .then(response => {
                        if (!response.ok) {
                            throw new Error('Network response was not ok');
                        }
                        return response.text();
                    })
                    .then(data => {
                        var latestVersion = data.split('\n')[0].trim().toLowerCase();

                        if (latestVersion && latestVersion !== currentVersion) {
                            $('#updateModal').modal('show');

                            $.get(changelogUrl, function (changelogData) {
                                var versionIndex = changelogData.indexOf('**Changelog**');
                                if (versionIndex !== -1) {
                                    var changelog = changelogData.substring(versionIndex);
                                    changelog = changelog.replace(/%0A/g, '\n').replace(/%0D/g, '');
                                    $('#changelogContent').text(changelog);
                                } else {
                                    $('#changelogContent').text('Changelog Tidak Tersedia');
                                }
                            }).fail(function() {
                                $('#changelogContent').text('Gagal memuat changelog');
                            });
                        }
                    })
                    .catch(error => {
                        console.error('Failed to check for update:', error);
                    });
            }

            checkUpdate();
        });
    </script>
</head>

<body>
    <!-- Update Modal -->
    <div class="modal fade" id="updateModal" tabindex="-1" role="dialog" aria-labelledby="updateModalLabel" aria-hidden="true">
        <div class="modal-dialog" role="document">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title" id="updateModalLabel">
                        Update Available | Branch <?php echo htmlspecialchars($branch_select); ?>
                    </h5>
                    <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                        <span aria-hidden="true">&times;</span>
                    </button>
                </div>
                <div class="modal-body">
                    <h5>Changelog:</h5>
                    <pre id="changelogContent"></pre>
                    <p>Update Dengan Bash Script:</p>
                    <div class="highlight highlight-source-shell position-relative overflow-auto">
                        <pre><span class="pl-c"># Copy Script Di Bawah Dan Paste Di Terminal</span>
bash -c "$(wget -qO - 'https://raw.githubusercontent.com/rtaserver/RakitanManager/<?php echo $branch_select; ?>/install.sh')"</pre>
                    </div>
                </div>
                <div class="modal-footer">
                    <a href="https://github.com/rtaserver/RakitanManager/blob/<?php echo htmlspecialchars($branch_select); ?>/CHANGELOG.md" 
                       target="_blank" class="btn btn-primary">Full Changelog</a>
                    <a href="https://github.com/rtaserver/RakitanManager/tree/package/<?php echo htmlspecialchars($branch_select); ?>" 
                       target="_blank" class="btn btn-primary">Download Dan Update</a>
                    <button type="button" class="btn btn-secondary" data-dismiss="modal">Close</button>
                </div>
            </div>
        </div>
    </div>

    <!-- Ads/Donate Modal -->
    <div class="modal fade" id="myModal" tabindex="-1" aria-labelledby="donateModalLabel" aria-hidden="true">
        <div class="modal-dialog">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title" id="donateModalLabel">Ads / Donate Me :)</h5>
                    <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                        <span aria-hidden="true">&times;</span>
                    </button>
                </div>
                <div class="modal-body">
                    <form method="post" id="modalForm">
                        <input type="hidden" name="csrf_token" value="<?php echo htmlspecialchars($_SESSION['csrf_token']); ?>">
                        <input type="hidden" name="modal_submit" value="1">
                        <div class="text-center">
                            <img src="./img/saweria.png" alt="Donate" style="max-width: 100%; height: auto;">
                        </div>
                        <br>
                        <div class="form-check">
                            <input type="checkbox" class="form-check-input" id="dontShow" name="dont_show">
                            <label class="form-check-label" for="dontShow">Jangan tampilkan lagi hari ini</label>
                        </div>
                        <a href="https://saweria.co/rizkikotet" target="_blank" rel="noopener noreferrer" class="btn btn-primary">Saweria</a>
                        <button type="submit" class="btn btn-primary" id="okButton" disabled>OK</button>
                        <button type="button" class="btn btn-secondary" data-dismiss="modal">Close</button>
                    </form>
                </div>
            </div>
        </div>
    </div>

    <div id="app">
        <?php include('navbar.php'); ?>
        <div class="container-fluid mt-5">
            <div class="row py-2">
                <div class="col-lg-8 col-md-9 mx-auto mt-3">
                    <div class="card">
                        <div class="card-header">
                            <div class="text-center">
                                <h4><i class="fa fa-home"></i> RAKITAN MANAGER</h4>
                            </div>
                        </div>
                        <div class="card-body">
                            <div class="text-center mb-3">
                                <img src="curent.svg" alt="Current Version">
                                <img alt="Latest Version" 
                                     src="https://img.shields.io/github/v/release/rtaserver/RakitanManager?display_name=tag&logo=openwrt&label=Latest%20Version&color=dark-green">
                            </div>

                            <div class="container">
                                <div class="row">
                                    <div class="col-md-6">
                                        <button type="button" class="btn btn-primary btn-block mb-3" 
                                                data-toggle="modal" data-target="#tambahModemModal" 
                                                <?php echo $rakitanmanager_status == 1 ? 'disabled' : ''; ?>>
                                            Tambah Modem
                                        </button>
                                    </div>
                                    <div class="col-md-6">
                                        <form method="POST">
                                            <input type="hidden" name="csrf_token" value="<?php echo htmlspecialchars($_SESSION['csrf_token']); ?>">
                                            <?php if ($rakitanmanager_status == 1): ?>
                                                <button type="submit" class="btn btn-danger btn-block mb-3" name="disable">
                                                    Stop Modem
                                                </button>
                                            <?php else: ?>
                                                <button type="submit" class="btn btn-success btn-block mb-3" 
                                                        name="enable" <?php echo $start_button_disabled; ?>>
                                                    Start Modem
                                                </button>
                                            <?php endif; ?>
                                        </form>
                                    </div>
                                </div>
                            </div>

                            <table class="table table-responsive">
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
                                    $status_class = '';
                                    switch ($modem["status"] ?? 0) {
                                        case -1:
                                            $status_class = 'bg-secondary text-white';
                                            break;
                                        case 2:
                                            $status_class = 'bg-warning';
                                            break;
                                    }
                                ?>
                                    <tr class="<?php echo $status_class; ?>">
                                        <td><?php echo htmlspecialchars($modem["nama"] ?? ''); ?></td>
                                        <td><?php echo htmlspecialchars($modem["jenis"] ?? ''); ?></td>
                                        <td><?php echo htmlspecialchars($modem["metodeping"] ?? ''); ?></td>
                                        <td><?php echo htmlspecialchars($modem["hostbug"] ?? ''); ?></td>
                                        <td>
                                            <button type="button" class="btn btn-dark btn-sm" 
                                                    onclick="updateStatus(<?php echo $index; ?>)" 
                                                    <?php echo $rakitanmanager_status == 1 ? 'disabled' : ''; ?>>
                                                <i class="fa <?php echo ($modem['status'] ?? 0) ? 'fa-ban' : 'fa-check'; ?>"></i>
                                            </button>
                                            <button type="button" class="btn btn-primary btn-sm" 
                                                    onclick="editModem(<?php echo $index; ?>)" 
                                                    <?php echo $rakitanmanager_status == 1 ? 'disabled' : ''; ?>>
                                                <i class="fa fa-pencil"></i>
                                            </button>
                                            <button type="button" class="btn btn-danger btn-sm" 
                                                    onclick="hapusModem(<?php echo $index; ?>)" 
                                                    <?php echo $rakitanmanager_status == 1 ? 'disabled' : ''; ?>>
                                                <i class="fa fa-trash"></i>
                                            </button>
                                        </td>
                                    </tr>
                                <?php endforeach; ?>
                                </tbody>
                            </table>

                            <div class="row mt-4">
                                <div class="col">
                                    <pre id="logContent" class="form-control text-left" 
                                         style="height: 200px; width: 100%; font-size: 80%; background-color: #f8f9fa; overflow-y: auto;"></pre>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
            <?php include('footer.php'); ?>
        </div>
    </div>

    <?php include("javascript.php"); ?>
    
    <?php if ($show_modal): ?>
    <script>
        $(document).ready(function() {
            $('#myModal').modal('show');
        });
    </script>
    <?php endif; ?>

    <script>
        // Modal form handling
        $('#modalForm').on('submit', function(e) {
            if ($('#dontShow').is(':checked')) {
                $('#myModal').modal('hide');
            }
        });
        
        $('#dontShow').change(function() {
            $('#okButton').prop('disabled', !$(this).is(':checked'));
        });

        // Modem management functions
        function editModem(index) {
            var modems = <?php echo json_encode($modems); ?>;
            var modem = modems[index];
            
            if (!modem) return;
            
            $('#edit_nama').val(modem.nama || '');
            $('#edit_cobaping').val(modem.cobaping || '');
            $('#edit_portmodem').val(modem.portmodem || '');
            $('#edit_interface').val(modem.interface || '');
            $('#edit_iporbit').val(modem.iporbit || '');
            $('#edit_usernameorbit').val(modem.usernameorbit || '');
            $('#edit_passwordorbit').val(modem.passwordorbit || '');
            $('#edit_metodeping').val(modem.metodeping || '');
            $('#edit_hostbug').val(modem.hostbug || '');
            $('#edit_androidid').val(modem.androidid || '');
            $('#edit_devicemodem').val(modem.devicemodem || '');
            $('#edit_modpes').val(modem.modpes || '');
            $('#edit_delayping').val(modem.delayping || '');
            $('#edit_script').val(modem.script || '');
            $('#edit_jenis').val(modem.jenis || '');
            
            // Show/hide fields based on modem type
            toggleEditFields(modem.jenis);
            
            $('#editIndex').val(index);
            $('#editModemModal').modal('show');
        }

        function updateStatus(index) {
            if (confirm('Toggle status modem ini?')) {
                window.location.href = '?update_status=' + index;
            }
        }

        function hapusModem(index) {
            if (confirm('Apakah Anda yakin ingin menghapus modem ini?')) {
                window.location.href = '?hapus_modem=' + index;
            }
        }

        // Field visibility toggle functions
        function toggleFields(jenis) {
            $('#rakitan_field, #orbit_field, #hp_field, #customscript_field').hide();
            
            switch(jenis) {
                case 'rakitan':
                    $('#rakitan_field').show();
                    break;
                case 'hp':
                    $('#hp_field').show();
                    break;
                case 'orbit':
                case 'hilink':
                case 'mf90':
                    $('#orbit_field').show();
                    break;
                case 'customscript':
                    $('#customscript_field').show();
                    break;
            }
        }

        function toggleEditFields(jenis) {
            $('#edit_rakitan_field, #edit_orbit_field, #edit_hp_field, #edit_customscript_field').hide();
            
            switch(jenis) {
                case 'rakitan':
                    $('#edit_rakitan_field').show();
                    break;
                case 'hp':
                    $('#edit_hp_field').show();
                    break;
                case 'orbit':
                case 'hilink':
                case 'mf90':
                    $('#edit_orbit_field').show();
                    break;
                case 'customscript':
                    $('#edit_customscript_field').show();
                    break;
            }
        }

        $(document).ready(function() {
            // Initialize field visibility for add form
            toggleFields($('#jenis').val());
            
            // Handle jenis change for add form
            $('#jenis').change(function() {
                toggleFields($(this).val());
            });

            // Handle jenis change for edit form
            $('#edit_jenis').change(function() {
                toggleEditFields($(this).val());
            });
        });

        // Form validation
        function validateFormTambah() {
            var jenis = $('#jenis').val();
            var nama = $('#nama').val().trim();
            var cobaping = $('#cobaping').val().trim();
            var hostbug = $('#hostbug').val().trim();
            var delayping = $('#delayping').val().trim();

            if (!jenis) {
                alert("Pilih jenis modem!");
                return false;
            }
            if (!nama) {
                alert("Nama modem harus diisi!");
                return false;
            }
            if (!cobaping || cobaping < 1) {
                alert("Percobaan gagal ping harus diisi dan minimal 1!");
                return false;
            }
            if (!hostbug) {
                alert("Host / Bug untuk ping harus diisi!");
                return false;
            }
            if (!delayping || delayping < 1) {
                alert("Jeda waktu detik harus diisi dan minimal 1!");
                return false;
            }

            // Validate based on modem type
            if (jenis === 'orbit' || jenis === 'hilink' || jenis === 'mf90') {
                var iporbit = $('#iporbit').val().trim();
                var usernameorbit = $('#usernameorbit').val().trim();
                var passwordorbit = $('#passwordorbit').val().trim();
                
                if (!iporbit || !usernameorbit || !passwordorbit) {
                    alert("Semua bidang IP Modem, Username, dan Password harus diisi!");
                    return false;
                }
            }

            if (jenis === 'customscript') {
                var script = $('#script').val().trim();
                if (!script) {
                    alert("Custom Script harus diisi!");
                    return false;
                }
            }

            return true;
        }

        function validateFormEdit() {
            var jenis = $('#edit_jenis').val();
            var nama = $('#edit_nama').val().trim();
            var cobaping = $('#edit_cobaping').val().trim();
            var hostbug = $('#edit_hostbug').val().trim();
            var delayping = $('#edit_delayping').val().trim();

            if (!jenis) {
                alert("Pilih jenis modem!");
                return false;
            }
            if (!nama) {
                alert("Nama modem harus diisi!");
                return false;
            }
            if (!cobaping || cobaping < 1) {
                alert("Percobaan gagal ping harus diisi dan minimal 1!");
                return false;
            }
            if (!hostbug) {
                alert("Host / Bug untuk ping harus diisi!");
                return false;
            }
            if (!delayping || delayping < 1) {
                alert("Jeda waktu detik harus diisi dan minimal 1!");
                return false;
            }

            // Validate based on modem type
            if (jenis === 'orbit' || jenis === 'hilink' || jenis === 'mf90') {
                var iporbit = $('#edit_iporbit').val().trim();
                var usernameorbit = $('#edit_usernameorbit').val().trim();
                var passwordorbit = $('#edit_passwordorbit').val().trim();
                
                if (!iporbit || !usernameorbit || !passwordorbit) {
                    alert("Semua bidang IP Modem, Username, dan Password harus diisi!");
                    return false;
                }
            }

            if (jenis === 'customscript') {
                var script = $('#edit_script').val().trim();
                if (!script) {
                    alert("Custom Script harus diisi!");
                    return false;
                }
            }

            return true;
        }
    </script>

    <!-- Modal Tambah Modem -->
    <div class="modal fade" id="tambahModemModal" tabindex="-1" aria-labelledby="tambahModemModalLabel" aria-hidden="true">
        <div class="modal-dialog modal-lg">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title" id="tambahModemModalLabel">Tambah Modem</h5>
                    <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                        <span aria-hidden="true">&times;</span>
                    </button>
                </div>
                <form id="tambahModemForm" onsubmit="return validateFormTambah()" method="post">
                    <input type="hidden" name="csrf_token" value="<?php echo htmlspecialchars($_SESSION['csrf_token']); ?>">
                    <div class="modal-body">
                        <div class="form-group">
                            <label for="jenis">Jenis Modem:</label>
                            <select name="jenis" id="jenis" class="form-control" required>
                                <option value="rakitan">Modem Rakitan</option>
                                <option value="hp">Modem HP</option>
                                <option value="orbit">Modem Huawei / Orbit</option>
                                <option value="hilink">Modem Hilink</option>
                                <option value="mf90">Modem MF90</option>
                                <option value="customscript">Custom Script</option>
                            </select>
                        </div>
                        
                        <div class="form-group">
                            <label for="nama">Nama Modem:</label>
                            <input type="text" id="nama" name="nama" class="form-control" placeholder="Nama Bebas" required>
                        </div>

                        <!-- Rakitan Fields -->
                        <div class="form-group" id="rakitan_field" style="display:none;">
                            <label for="portmodem">Pilih Port Modem:</label>
                            <select name="portmodem" id="portmodem" class="form-control">
                                <?php for ($i = 0; $i <= 7; $i++): ?>
                                    <option value="/dev/ttyUSB<?php echo $i; ?>">/dev/ttyUSB<?php echo $i; ?></option>
                                <?php endfor; ?>
                                <?php for ($i = 0; $i <= 7; $i++): ?>
                                    <option value="/dev/ttyACM<?php echo $i; ?>">/dev/ttyACM<?php echo $i; ?></option>
                                <?php endfor; ?>
                            </select>
                            
                            <label for="interface" class="mt-2">Interface Modem Manager:</label>
                            <select name="interface" id="interface" class="form-control">
                                <?php foreach ($interface_modem as $interface): ?>
                                    <option value="<?php echo htmlspecialchars($interface); ?>">
                                        <?php echo htmlspecialchars($interface); ?>
                                    </option>
                                <?php endforeach; ?>
                            </select>
                        </div>

                        <!-- Orbit/Hilink/MF90 Fields -->
                        <div class="form-group" id="orbit_field" style="display:none;">
                            <label for="iporbit">IP Modem:</label>
                            <input type="text" id="iporbit" name="iporbit" class="form-control" placeholder="192.168.8.1" value="192.168.8.1">
                            
                            <label for="usernameorbit" class="mt-2">Username:</label>
                            <input type="text" id="usernameorbit" name="usernameorbit" class="form-control" placeholder="admin" value="admin">
                            
                            <label for="passwordorbit" class="mt-2">Password:</label>
                            <input type="password" id="passwordorbit" name="passwordorbit" class="form-control" placeholder="admin" value="admin">
                        </div>

                        <!-- HP Fields -->
                        <div class="form-group" id="hp_field" style="display:none;">
                            <label for="androidid">Pilih Android Device:</label>
                            <select name="androidid" id="androidid" class="form-control">
                                <?php if (empty($androidid)): ?>
                                    <option value="">Tidak ada Android yang terdeteksi</option>
                                <?php else: ?>
                                    <?php foreach ($androidid as $android_id): ?>
                                        <option value="<?php echo htmlspecialchars($android_id); ?>">
                                            <?php echo htmlspecialchars($android_id); ?>
                                        </option>
                                    <?php endforeach; ?>
                                <?php endif; ?>
                            </select>
                            
                            <label for="modpes" class="mt-2">Versi Modpes:</label>
                            <select name="modpes" id="modpes" class="form-control">
                                <option value="modpesv1">Mode Pesawat V1</option>
                                <option value="modpesv2">Mode Pesawat V2</option>
                            </select>
                        </div>

                        <!-- Custom Script Fields -->
                        <div class="form-group" id="customscript_field" style="display:none;">
                            <label for="script">Custom Script:</label>
                            <textarea id="script" name="script" class="form-control" rows="5" placeholder="#!/bin/bash">#!/bin/bash</textarea>
                        </div>

                        <!-- Common Fields -->
                        <div class="form-group">
                            <label for="metodeping">Pilih Metode PING:</label>
                            <select id="metodeping" name="metodeping" class="form-control" required>
                                <option value="icmp">ICMP</option>
                                <option value="curl">CURL</option>
                                <option value="http">HTTP</option>
                                <option value="https">HTTPS</option>
                            </select>
                        </div>

                        <div class="form-group">
                            <label for="hostbug">Host / Bug Untuk Ping (Multi Host):</label>
                            <input type="text" id="hostbug" name="hostbug" class="form-control" 
                                   placeholder="google.com facebook.com" value="google.com facebook.com" required>
                        </div>

                        <div class="form-group">
                            <label for="devicemodem">Device Modem Untuk Cek PING:</label>
                            <select name="devicemodem" id="devicemodem" class="form-control">
                                <option value="disabled">Jangan Gunakan | Default</option>
                                <?php foreach ($interfaces as $devicemodem): ?>
                                    <option value="<?php echo htmlspecialchars($devicemodem); ?>">
                                        <?php echo htmlspecialchars($devicemodem); ?>
                                    </option>
                                <?php endforeach; ?>
                            </select>
                        </div>

                        <div class="form-group">
                            <label for="cobaping">Percobaan Ping Gagal:</label>
                            <input type="number" id="cobaping" name="cobaping" class="form-control" 
                                   placeholder="2" value="2" min="1" max="100" required>
                        </div>

                        <div class="form-group">
                            <label for="delayping">Jeda Waktu (Detik) Sebelum Cek PING:</label>
                            <input type="number" id="delayping" name="delayping" class="form-control" 
                                   placeholder="3" value="3" min="1" max="3600" required>
                        </div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-dismiss="modal">Tutup</button>
                        <button type="submit" name="tambah_modem" class="btn btn-primary">Simpan</button>
                    </div>
                </form>
            </div>
        </div>
    </div>

    <!-- Modal Edit Modem -->
    <div class="modal fade" id="editModemModal" tabindex="-1" aria-labelledby="editModemModalLabel" aria-hidden="true">
        <div class="modal-dialog modal-lg">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title" id="editModemModalLabel">Edit Modem</h5>
                    <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                        <span aria-hidden="true">&times;</span>
                    </button>
                </div>
                <form id="editModemForm" onsubmit="return validateFormEdit()" method="post">
                    <input type="hidden" name="csrf_token" value="<?php echo htmlspecialchars($_SESSION['csrf_token']); ?>">
                    <input type="hidden" name="index" id="editIndex">
                    <div class="modal-body">
                        <div class="form-group">
                            <label for="edit_jenis">Jenis Modem:</label>
                            <select name="edit_jenis" id="edit_jenis" class="form-control" required>
                                <option value="rakitan">Modem Rakitan</option>
                                <option value="hp">Modem HP</option>
                                <option value="orbit">Modem Huawei / Orbit</option>
                                <option value="hilink">Modem Hilink</option>
                                <option value="mf90">Modem MF90</option>
                                <option value="customscript">Custom Script</option>
                            </select>
                        </div>
                        
                        <div class="form-group">
                            <label for="edit_nama">Nama Modem:</label>
                            <input type="text" id="edit_nama" name="edit_nama" class="form-control" placeholder="Nama Bebas" required>
                        </div>

                        <!-- Rakitan Fields -->
                        <div class="form-group" id="edit_rakitan_field" style="display:none;">
                            <label for="edit_portmodem">Pilih Port Modem:</label>
                            <select name="edit_portmodem" id="edit_portmodem" class="form-control">
                                <?php for ($i = 0; $i <= 7; $i++): ?>
                                    <option value="/dev/ttyUSB<?php echo $i; ?>">/dev/ttyUSB<?php echo $i; ?></option>
                                <?php endfor; ?>
                                <?php for ($i = 0; $i <= 7; $i++): ?>
                                    <option value="/dev/ttyACM<?php echo $i; ?>">/dev/ttyACM<?php echo $i; ?></option>
                                <?php endfor; ?>
                            </select>
                            
                            <label for="edit_interface" class="mt-2">Interface Modem Manager:</label>
                            <select name="edit_interface" id="edit_interface" class="form-control">
                                <?php foreach ($interface_modem as $interface): ?>
                                    <option value="<?php echo htmlspecialchars($interface); ?>">
                                        <?php echo htmlspecialchars($interface); ?>
                                    </option>
                                <?php endforeach; ?>
                            </select>
                        </div>

                        <!-- Orbit/Hilink/MF90 Fields -->
                        <div class="form-group" id="edit_orbit_field" style="display:none;">
                            <label for="edit_iporbit">IP Modem:</label>
                            <input type="text" id="edit_iporbit" name="edit_iporbit" class="form-control" placeholder="192.168.8.1">
                            
                            <label for="edit_usernameorbit" class="mt-2">Username:</label>
                            <input type="text" id="edit_usernameorbit" name="edit_usernameorbit" class="form-control" placeholder="admin">
                            
                            <label for="edit_passwordorbit" class="mt-2">Password:</label>
                            <input type="password" id="edit_passwordorbit" name="edit_passwordorbit" class="form-control" placeholder="admin">
                        </div>

                        <!-- HP Fields -->
                        <div class="form-group" id="edit_hp_field" style="display:none;">
                            <label for="edit_androidid">Pilih Android Device:</label>
                            <select name="edit_androidid" id="edit_androidid" class="form-control">
                                <?php if (empty($androidid)): ?>
                                    <option value="">Tidak ada Android yang terdeteksi</option>
                                <?php else: ?>
                                    <?php foreach ($androidid as $android_id): ?>
                                        <option value="<?php echo htmlspecialchars($android_id); ?>">
                                            <?php echo htmlspecialchars($android_id); ?>
                                        </option>
                                    <?php endforeach; ?>
                                <?php endif; ?>
                            </select>
                            
                            <label for="edit_modpes" class="mt-2">Versi Modpes:</label>
                            <select name="edit_modpes" id="edit_modpes" class="form-control">
                                <option value="modpesv1">Mode Pesawat V1</option>
                                <option value="modpesv2">Mode Pesawat V2</option>
                            </select>
                        </div>

                        <!-- Custom Script Fields -->
                        <div class="form-group" id="edit_customscript_field" style="display:none;">
                            <label for="edit_script">Custom Script:</label>
                            <textarea id="edit_script" name="edit_script" class="form-control" rows="5" placeholder="#!/bin/bash"></textarea>
                        </div>

                        <!-- Common Fields -->
                        <div class="form-group">
                            <label for="edit_metodeping">Pilih Metode PING:</label>
                            <select id="edit_metodeping" name="edit_metodeping" class="form-control" required>
                                <option value="icmp">ICMP</option>
                                <option value="curl">CURL</option>
                                <option value="http">HTTP</option>
                                <option value="https">HTTPS</option>
                            </select>
                        </div>

                        <div class="form-group">
                            <label for="edit_hostbug">Host / Bug Untuk Ping (Multi Host):</label>
                            <input type="text" id="edit_hostbug" name="edit_hostbug" class="form-control" 
                                   placeholder="google.com facebook.com" required>
                        </div>

                        <div class="form-group">
                            <label for="edit_devicemodem">Device Modem Untuk Cek PING:</label>
                            <select name="edit_devicemodem" id="edit_devicemodem" class="form-control">
                                <option value="disabled">Jangan Gunakan | Default</option>
                                <?php foreach ($interfaces as $devicemodem): ?>
                                    <option value="<?php echo htmlspecialchars($devicemodem); ?>">
                                        <?php echo htmlspecialchars($devicemodem); ?>
                                    </option>
                                <?php endforeach; ?>
                            </select>
                        </div>

                        <div class="form-group">
                            <label for="edit_cobaping">Percobaan Ping Gagal:</label>
                            <input type="number" id="edit_cobaping" name="edit_cobaping" class="form-control" 
                                   placeholder="2" min="1" max="100" required>
                        </div>

                        <div class="form-group">
                            <label for="edit_delayping">Jeda Waktu (Detik) Sebelum Cek PING:</label>
                            <input type="number" id="edit_delayping" name="edit_delayping" class="form-control" 
                                   placeholder="3" min="1" max="3600" required>
                        </div>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-dismiss="modal">Tutup</button>
                        <button type="submit" name="edit_modem" class="btn btn-primary">Simpan</button>
                    </div>
                </form>
            </div>
        </div>
    </div>

</body>
</html>