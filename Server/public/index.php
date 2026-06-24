<?php
declare(strict_types=1);

require_once dirname(__DIR__) . '/src/Config.php';
require_once dirname(__DIR__) . '/src/Database.php';
require_once dirname(__DIR__) . '/src/Http.php';
require_once dirname(__DIR__) . '/src/TelemetryValidator.php';
require_once dirname(__DIR__) . '/src/Api.php';

use WinTune\Config;
use WinTune\Database;
use WinTune\Http;
use WinTune\Api;

$config = Config::load(dirname(__DIR__) . '/.env');
$db = Database::connect($config);
$api = new Api($config, $db);
$api->handle(Http::request());
