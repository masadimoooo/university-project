// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {EProp} from "../src/eProp.sol";

contract DeployEProp is Script {
    string private imageUri = "https://ipfs.io/ipfs/bafkreifiunseqevb4vlep5up5wrvw7fvosii4ms2jcpjjzkqmiyclgakh4";

    function run() external returns (EProp) {
        vm.startBroadcast();
        EProp eprop = new EProp(imageUri);
        vm.stopBroadcast();
        return eprop;
    }
}
