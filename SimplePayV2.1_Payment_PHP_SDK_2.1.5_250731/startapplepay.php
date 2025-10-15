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

$trx = new SimplePayStartApplePay;

$json = file_get_contents('php://input');
$request = (array) json_decode($json, true, 8);


$trx->addData('currency', $request['currencyCode']);
$trx->addConfig($config);


// Domain for Apple Pay
//-----------------------------------------------------------------------------------------
$trx->addData('domain', 'payusdk.simplelabs.hu');


//ORDER PRICE/TOTAL
//-----------------------------------------------------------------------------------------
//$total = $request['total']['amount'];
$trx->addData('total', $request['total']['amount']);

//ORDER ITEMS
//-----------------------------------------------------------------------------------------
/*
$trx->addItems(
    array(
        'ref' => 'Product ID 1',
        'title' => 'Product name 1',
        'desc' => 'Product description 1',
        'amount' => '1',
        'price' => '5',
        'tax' => '0',
        )
);

$trx->addItems(
    array(
        'ref' => 'Product ID 2',
        'title' => 'Product name 2',
        'desc' => 'Product description 2',
        'amount' => '1',
        'price' => '2',
        'tax' => '0',
        )
);
*/


// SHIPPING COST
//-----------------------------------------------------------------------------------------
//$trx->addData('shippingCost', 20);


// DISCOUNT
//-----------------------------------------------------------------------------------------
//$trx->addData('discount', 10);


// ORDER REFERENCE NUMBER
// uniq oreder reference number in the merchant system
//-----------------------------------------------------------------------------------------
$trx->addData('orderRef', str_replace(array('.', ':', '/'), "", 'ApplePay_' . @$_SERVER['SERVER_ADDR']) . @date("U", time()) . rand(1000, 9999));


// CUSTOMER
// customer's name
//-----------------------------------------------------------------------------------------
//$trx->addData('customer', 'v2 SimplePay Teszt');


// customer's registration mehod
// 01: guest
// 02: registered
// 05: third party
//-----------------------------------------------------------------------------------------
//$trx->addData('threeDSReqAuthMethod', '02');


// EMAIL
// customer's email
//-----------------------------------------------------------------------------------------
$trx->addData('customerEmail', 'sdk_test@simplepay.com');


// LANGUAGE
// HU, EN, DE, etc.
//-----------------------------------------------------------------------------------------
$trx->addData('language', 'HU');


// TIMEOUT
// 2018-09-15T11:25:37+02:00
//-----------------------------------------------------------------------------------------
$timeoutInSec = 60 * 60 * 24;
$timeout = @date("c", time() + $timeoutInSec);
$timeout = '2025-09-15T11:25:37+02:00';
$trx->addData('timeout', $timeout);


// INVOICE DATA
//-----------------------------------------------------------------------------------------
//$trx->addGroupData('invoice', 'name', 'SimplePay V2 Tester');
//$trx->addGroupData('invoice', 'company', '');
//$trx->addGroupData('invoice', 'country', 'hu');
//$trx->addGroupData('invoice', 'state', 'Budapest');
//$trx->addGroupData('invoice', 'city', 'Budapest');
//$trx->addGroupData('invoice', 'zip', '1111');
//$trx->addGroupData('invoice', 'address', 'Address 1');
//$trx->addGroupData('invoice', 'address2', 'Address 2');
//$trx->addGroupData('invoice', 'phone', '06201234567');


// DELIVERY DATA
//-----------------------------------------------------------------------------------------
/*
$trx->addGroupData('delivery', 'name', 'SimplePay V2 Tester');
$trx->addGroupData('delivery', 'company', '');
$trx->addGroupData('delivery', 'country', 'hu');
$trx->addGroupData('delivery', 'state', 'Budapest');
$trx->addGroupData('delivery', 'city', 'Budapest');
$trx->addGroupData('delivery', 'zip', '1111');
$trx->addGroupData('delivery', 'address', 'Address 1');
$trx->addGroupData('delivery', 'address2', '');
$trx->addGroupData('delivery', 'phone', '06203164978');
*/


//create transaction in SimplePay system
//-----------------------------------------------------------------------------------------
$trx->runStartApplePay();


// RESPONSE
//-----------------------------------------------------------------------------------------
$returnData = $trx->getReturnData();
unset($returnData["responseBody"]);
unset($returnData["responseSignature"]); 
unset($returnData["responseSignatureValid"]);
$returnData["request"] = $request;
print json_encode($returnData);


