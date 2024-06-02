<footer class="text-center">
    <br>
    <script>
        function checkConnection() {
            return navigator.onLine;
        }
    </script>
    <script type='text/javascript' src='js/trbtn-overlay.js'></script>
    <script type='text/javascript'
        class='troverlay'>(function () {
            if (!checkConnection()) {
                // Jika tidak ada koneksi, hentikan proses
                return;
            }
            var trbtnId = trbtnOverlay.init('Dukung Saya di Trakteer', '#be1e2d', 'https://trakteer.id/rtaserver/tip/embed/modal', 'img/trbtn-icon.png', '40', 'inline'); trbtnOverlay.draw(trbtnId); 
        }
    )();
    </script>
    <script type='text/javascript' src='js/trbtn.js'></script>
    <script
        type='text/javascript'>(function () {
            if (!checkConnection()) {
                // Jika tidak ada koneksi, hentikan proses
                return;
            } 
            var trbtnId = trbtn.init('Dukung Saya di Saweria', '#FFC147', 'https://saweria.co/rizkikotet', 'img/saweria.ico', '40'); trbtn.draw(trbtnId); 
        }
    )();
    </script>
    <br>
    <br>
    <font color="black">© 2024 Modem Rakitan Manager.</a>
</footer>