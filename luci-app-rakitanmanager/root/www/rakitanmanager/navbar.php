<?php
$url_array = explode('/', $_SERVER['REQUEST_URI']);
$url = end($url_array);
?>
<nav class="navbar navbar-expand-lg navbar-dark bg-dark fixed-top shadow">
    <div class="container-fluid">
        <a class="navbar-brand fw-bold" href="index.php">
            <i class="fas fa-wifi me-2"></i>RAKITAN MANAGER
        </a>
        <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarNav"
            aria-controls="navbarNav" aria-expanded="false" aria-label="Toggle navigation">
            <span class="navbar-toggler-icon"></span>
        </button>
        <div class="collapse navbar-collapse" id="navbarNav">
            <ul class="navbar-nav me-auto">
                <li class="nav-item">
                    <a class="nav-link <?php if ($url === 'index.php') echo 'active'; ?>" href="index.php">
                        <i class="fas fa-home me-1"></i> Modem Rakitan
                    </a>
                </li>
                <li class="nav-item">
                    <a class="nav-link <?php if ($url === 'hostip.php') echo 'active'; ?>" href="hostip.php">
                        <i class="fas fa-globe me-1"></i> Hostname To IP
                    </a>
                </li>
                <li class="nav-item">
                    <a class="nav-link <?php if ($url === 'telegram.php') echo 'active'; ?>" href="telegram.php">
                        <i class="fab fa-telegram-plane me-1"></i> Bot Telegram
                    </a>
                </li>
                <li class="nav-item">
                    <a class="nav-link <?php if ($url === 'about.php') echo 'active'; ?>" href="about.php">
                        <i class="fas fa-info-circle me-1"></i> About
                    </a>
                </li>
            </ul>
            <div class="d-flex">
                <button id="theme-toggle" class="btn btn-outline-light me-2">
                    <i class="fas fa-moon"></i>
                </button>
            </div>
        </div>
    </div>
</nav>
