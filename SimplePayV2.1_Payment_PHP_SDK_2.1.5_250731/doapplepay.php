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
 *   along with this program.  If not, see http://www.gnu.org/licenses
 *
 * @category  SDK
 * @package   SimplePayV2_SDK
 * @author    SimplePay IT Support <itsupport@simplepay.com>
 * @copyright 2025 SimplePay Zrt.
 * @license   http://www.gnu.org/licenses/gpl-3.0.html  GNU GENERAL PUBLIC LICENSE (GPL V3.0)
 * @link      http://simplepartner.hu/online_fizetesi_szolgaltatas.html
 */

//Optional error riporting
error_reporting(E_ALL);
ini_set('display_errors', '1');

//Import config data
require_once 'src/config.php';

//Import SimplePayment class
require_once 'src/SimplePayV21.php';

$trx = new SimplePayDoApplePay;

$currency = 'HUF';
$trx->addData('currency', $currency);

$trx->addConfig($config);

$json = file_get_contents('php://input');
$request = (array) json_decode($json);
$trx->addData('transactionId', $request['transactionId']);
$trx->addData('applePayToken', $request['applePayToken']);

// Run Apple Pay authirization
//-----------------------------------------------------------------------------------------
$trx->runDoApplePay();

$returnData = $trx->getReturnData();
unset($returnData["responseBody"]);
unset($returnData["responseSignature"]); 
unset($returnData["responseSignatureValid"]);
print json_encode($returnData);
exit;


