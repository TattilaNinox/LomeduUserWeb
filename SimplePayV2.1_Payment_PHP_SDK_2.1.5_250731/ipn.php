<?php

/**
 *  Copyright (C) 2025 SimplePay Zrt.
 *
 *  PHP version 8.3
 *
 *  This program is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation, either version 3 of the License, or
 *   (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *   along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * @category  SDK
 * @package   SimplePayV2
 * @author    SimplePay IT Support <itsupport@simplepay.com>
 * @copyright 2025 SimplePay Zrt.
 * @license   http://www.gnu.org/licenses/gpl-3.0.html  GNU GENERAL PUBLIC LICENSE (GPL V3.0)
 * @link      http://simplepartner.hu/online_fizetesi_szolgaltatas.html
 */

//header('Content-Type: text/html; charset=utf-8');
header('Content-Type: application/json; charset=utf-8');

//Optional error riporting
error_reporting(E_ALL);
ini_set('display_errors', '1');

//Import config data
require_once 'src/config.php';

//Import SimplePayment class
require_once 'src/SimplePayV21.php';

$json = file_get_contents('php://input');

$input = (array) json_decode($json);

$trx = new SimplePayIpn;

$trx->addConfig($config);

//check signature and confirm IPN
//-----------------------------------------------------------------------------------------
if ($trx->isIpnSignatureCheck($json)) {
    /**
     * Generates all response
     * Puts signature into header
     * Print response body
     *
     * Use this OR getIpnConfirmContent
     */
    $trx->runIpnConfirm();

    /**
     * Generates all response
     * Gets signature and response body
     *
     * You must set signeature in header and you must print response body!
     *
     * Use this OR runIpnConfirm()
     */
    //$confirm = $trx->getIpnConfirmContent();

}

//no need to print further information
exit;
