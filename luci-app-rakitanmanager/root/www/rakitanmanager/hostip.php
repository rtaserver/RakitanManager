<!doctype html>
<html lang="en">

<head>
    <?php
    $title = "Home";
    include ("head.php");
    ?>
    <script src="lib/vendor/jquery/jquery-3.6.0.slim.min.js"></script>
    <script>
        $(document).ready(function () {
            $("form").on("submit", function (e) {
                e.preventDefault();
                var hostname = $("#hostname").val();
                $("button[type='submit']").prop("disabled", true);
                $.get("get_ip.php", { hostname: hostname }, function (data) {
                    $(".result").html(data);
                    $("button[type='submit']").prop("disabled", false);
                });
            });
        });
    </script>
</head>

<body>
    <div id="app">
        <?php include ('navbar.php'); ?>
        <form method="POST" class="mt-5">
            <div class="container-fluid">
                <div class="row py-2">
                    <div class="col-lg-8 col-md-9 mx-auto mt-3">
                        <div class="card">
                            <div class="card-header">
                                <div class="text-center">
                                    <h4><i class="fa fa-home"></i> HOST TO IP</h4>
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
                                    </div>
                                    <div class="container">
                                        <h1 class="mt-5">Hostname to IP Converter</h1>
                                        <div class="form-group">
                                            <label for="hostname">Masukan Hostname:</label>
                                            <input type="text" class="form-control" id="hostname" name="hostname"
                                                required>
                                        </div>
                                        <button type="submit" class="btn btn-primary">Convert</button>
                                        <div class="result mt-3"></div>
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
</body>

</html>