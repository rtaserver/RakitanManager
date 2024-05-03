<?php
$url_array = explode('/', $_SERVER['REQUEST_URI']);
$url = end($url_array);
?>
<nav class="navbar navbar-expand-lg navbar-light" style="background-color: #f8f9fa;">
    <a class="navbar-brand" href="#">RAKITAN MANAGER</a>
    <button class="navbar-toggler" type="button" data-toggle="collapse" data-target="#navbarNavDropdown"
        aria-controls="navbarNavDropdown" aria-expanded="false" aria-label="Toggle navigation">
        <a>Menu</a>
        <!--<span class="navbar-toggler-icon"></span>-->
    </button>
    <div class="collapse navbar-collapse" id="navbarNavDropdown">
        <ul class="navbar-nav mr-auto">
            <li class="nav-item <?php if ($url === 'index.php')
                echo 'active'; ?>">
                <a class="nav-link" href="index.php"><i class="fa fa-home"></i> Modem Rakitan <span
                        class="sr-only">(current)</span></a>
            </li>
            <li class="nav-item <?php if ($url === 'hostip.php')
                echo 'active'; ?>">
                <a class="nav-link" href="hostip.php"><i class="fa fa-bomb"></i> Hostname To IP</a>
            </li>
            <li class="nav-item <?php if ($url === 'telegram.php')
                echo 'active'; ?>">
                <a class="nav-link" href="telegram.php"><i class="fa fa-telegram"></i> Bot Telegram</a>
            </li>
            <li class="nav-item <?php if ($url === 'pengaturan.php')
                echo 'active'; ?>">
                <a class="nav-link" href="pengaturan.php"><i class="fa fa-gear"></i> Pengaturan</a>
            </li>
            <li class="nav-item <?php if ($url === 'about.php')
                echo 'active'; ?>">
                <a class="nav-link" href="about.php"><i class="fa fa-info"></i> About</a>
            </li>
        </ul>
    </div>
</nav>