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

//Optional error riporting
error_reporting(E_ALL);
ini_set('display_errors', '1');

 //Import config data
require_once 'src/config.php';

//Import SimplePayment class
require_once 'src/SimplePayV21.php';

$trx = new SimplePayBack;

$trx->addConfig($config);


//result
//-----------------------------------------------------------------------------------------
$result = array();
if (isset($_REQUEST['r']) && isset($_REQUEST['s'])) {
    if ($trx->isBackSignatureCheck($_REQUEST['r'], $_REQUEST['s'])) {
        $result = $trx->getRawNotification();
    }
}


// test data
//-----------------------------------------------------------------------------------------
print "<pre>";
print '<a href="index.html">INDEX</a>';
print "<br/><br/>";
print_r($result);
print "</pre>";


if (count($result) > 0) {

    // QUERY
    print '<a href="query.php?orderRef=' . $result['o'] . '&transactionId=' . $result['t'] . '&merchant=' . $result['m'] . '"> QUERY: ' . $result['t'] . '</a>';
    print "<br/><br/>";

    // REFUND
    print '<a href="refund.php?orderRef=' . $result['o'] . '&transactionId=' . $result['t'] . '&merchant=' . $result['m'] . '"> REFUND 5 HUF</a>';
    print "<br/><br/>";

    print "Kétlépcsős tranzakció lezárása esetén<br/><br/>";
    // FINISH FULL
    print '<a href="finish.php?orderRef=' . $result['o'] . '&transactionId=' . $result['t'] . '&merchant=' . $result['m'] . '&originalTotal=25&approveTotal=25"> FINISH 25 HUF (terhelés teljes összeggel)</a>';
    print "<br/><br/>";

    // FINISH 20
    print '<a href="finish.php?orderRef=' . $result['o'] . '&transactionId=' . $result['t'] . '&merchant=' . $result['m'] . '&originalTotal=25&approveTotal=10"> FINISH 10 HUF (terhelés a foglaltnál kisebb összeggel)</a>';
    print "<br/><br/>";

    // FINISH 0
    print '<a href="finish.php?orderRef=' . $result['o'] . '&transactionId=' . $result['t'] . '&merchant=' . $result['m'] . '&originalTotal=25&approveTotal=0"> FINISH 0 HUF (foglalás feloldása)</a>';
    print "<br/><br/>";

}
