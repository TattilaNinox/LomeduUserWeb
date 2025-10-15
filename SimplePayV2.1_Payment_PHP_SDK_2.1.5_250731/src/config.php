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

$config = [
    //HUF
    'HUF_MERCHANT' => "",            //merchant account ID (HUF)
    'HUF_SECRET_KEY' => "",          //secret key for account ID (HUF)
    
    //EUR
    'EUR_MERCHANT' => "",            //merchant account ID (EUR)
    'EUR_SECRET_KEY' => "",          //secret key for account ID (EUR)

    //USD
    'USD_MERCHANT' => "",            //merchant account ID (USD)
    'USD_SECRET_KEY' => "",          //secret key for account ID (USD)

    'SANDBOX' => true,

    //common return URL
    'URL' => 'http://' . $_SERVER['HTTP_HOST'] . '/back.php',

    //optional uniq URL for events
    /*
    'URLS_SUCCESS' => 'http://' . $_SERVER['HTTP_HOST'] . '/success.php',       //url for successful payment
    'URLS_FAIL' => 'http://' . $_SERVER['HTTP_HOST'] . '/fail.php',             //url for unsuccessful
    'URLS_CANCEL' => 'http://' . $_SERVER['HTTP_HOST'] . '/cancel.php',         //url for cancell on payment page
    'URLS_TIMEOUT' => 'http://' . $_SERVER['HTTP_HOST'] . '/timeout.php',       //url for payment page timeout
    */

    'GET_DATA' => (isset($_GET['r']) && isset($_GET['s'])) ? ['r' => $_GET['r'], 's' => $_GET['s']] : [],
    'POST_DATA' => $_POST,
    'SERVER_DATA' => $_SERVER,

    'LOGGER' => true,                              //basic transaction log
    'LOG_PATH' => 'log',                           //path of log file

    //3DS
    'AUTOCHALLENGE' => true,                      //in case of unsuccessful payment with registered card run automatic challange
];

