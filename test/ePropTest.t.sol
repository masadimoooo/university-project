// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {EProp} from "../src/eProp.sol";
import {DeployEProp} from "../script/DeployeProp.s.sol";
import {MintNft} from "../script/interaction.s.sol";
import {Strings} from "@OpenZeppelin/contracts/utils/Strings.sol";
import {Base64} from "@OpenZeppelin/contracts/utils/Base64.sol";

contract EPropTest is Test {
    using Strings for uint256;

    enum PropType {
        LAND,
        HOUSE,
        APARTMENT
    }

    DeployEProp public deployer;
    EProp public eProp;
    address public USER = makeAddr("User");
    address public USER2 = makeAddr("User2");
    uint256 constant SELL_PRICE = 1 ether;
    uint256 bidAmount = SELL_PRICE * 2;

    function setUp() public {
        deployer = new DeployEProp();
        eProp = deployer.run();
    }

    function testMintProp() public {
        eProp.mintProp(USER, 44, 65, 0, 0, 0);
        EProp.PropSpec memory specs;
        (specs.length, specs.width) = eProp.getSpec(0);
        console.log(specs.length);
        console.log(specs.width);
    }

    function testTokenUri() public {
        eProp.mintProp(USER, 44, 65, 1, 1, 0);

        console.log(eProp.tokenURI(0));
    }

    //------------- sale tests -------------

    function testListTokenForSale() public {
        eProp.mintProp(USER, 44, 65, 1, 1, 0);

        vm.prank(USER);
        vm.expectRevert();
        eProp.listTokenForSale(2, SELL_PRICE);

        vm.prank(USER);
        eProp.listTokenForSale(0, SELL_PRICE);

        vm.prank(USER);
        vm.expectRevert(EProp.EProp__AlreadyOnSaleOrInAuction.selector);
        eProp.listTokenForSale(0, SELL_PRICE);

        assert(eProp.tokenIdToIsListed(0));
        assert(eProp.getTokenPrice(0) == SELL_PRICE);
    }

    function testPayForListedToken() public {
        eProp.mintProp(USER, 44, 65, 1, 1, 0);

        vm.prank(USER);
        eProp.listTokenForSale(0, SELL_PRICE);

        hoax(USER2, SELL_PRICE);
        eProp.payForToken{value: SELL_PRICE}(0);

        assert(eProp.ownerOf(0) == USER2);
        assert(USER.balance == SELL_PRICE);
    }

    function testSellToken() public {
        eProp.mintProp(USER, 44, 65, 1, 1, 0);

        vm.prank(USER);
        eProp.submitBuyer(USER2, 0, SELL_PRICE);

        hoax(USER2, 2 ether);
        console.log(address(USER2));
        eProp.payForToken{value: SELL_PRICE}(0);

        assert(eProp.ownerOf(0) == USER2);
        assert(USER.balance == SELL_PRICE);
    }

    function testSubmitBuyerRevertWhenNotTokenOwner() public {
        eProp.mintProp(USER, 44, 65, 1, 1, 0);

        vm.expectRevert(EProp.EProp__NotTokenOwnerOrApproved.selector);
        eProp.submitBuyer(USER2, 0, SELL_PRICE);
    }

    function testSubmitBuyerAgainRevert() public {
        eProp.mintProp(USER, 44, 65, 1, 1, 0);

        vm.prank(USER);
        eProp.submitBuyer(USER2, 0, SELL_PRICE);

        vm.prank(USER);
        vm.expectRevert(EProp.EProp__AlreadyOnSaleOrInAuction.selector);
        eProp.submitBuyer(USER2, 0, SELL_PRICE);
    }

    function testSubmitBuyerRevertWhenBuyerIsOwner() public {
        eProp.mintProp(USER, 44, 65, 1, 1, 0);

        vm.expectRevert(EProp.EProp__WrongTokenIdEntered.selector);
        vm.prank(USER);
        eProp.submitBuyer(USER, 0, SELL_PRICE);
    }

    function testCancelSale() public {
        eProp.mintProp(USER, 44, 65, 1, 1, 0);

        vm.prank(USER);
        eProp.submitBuyer(USER2, 0, SELL_PRICE);

        vm.prank(USER);
        eProp.cancelSaleOrUnlist(0);

        vm.prank(USER);
        address buyer = eProp.getBuyer(0);

        vm.prank(USER);
        uint256 price = eProp.getTokenPrice(0);

        assert(buyer == address(0));
        assert(price == 0);

        vm.prank(USER);
        eProp.listTokenForSale(0, SELL_PRICE);

        vm.prank(USER);
        eProp.cancelSaleOrUnlist(0);

        vm.prank(USER);
        price = eProp.getTokenPrice(0);
        assert(price == 0);
    }

    function testCancelSaleRevertWhenNotOnSale() public {
        eProp.mintProp(USER, 44, 65, 1, 1, 0);

        vm.expectRevert(EProp.EProp__TokenNotOnSaleOrListed.selector);
        vm.prank(USER);
        eProp.cancelSaleOrUnlist(0);
    }

    function testPayForTokenRevertWhenNotBuyer() public {
        eProp.mintProp(USER, 44, 65, 1, 1, 0);

        vm.prank(USER);
        eProp.submitBuyer(USER2, 0, SELL_PRICE);

        hoax(address(3), 2 ether);
        vm.expectRevert(EProp.EProp__TokenNotForSaleForThisAddressOrListed.selector);
        eProp.payForToken{value: SELL_PRICE}(0);
    }

    function testPayForTokenRevertWhenTokenNotForSale() public {
        eProp.mintProp(USER, 44, 65, 1, 1, 0);
        eProp.mintProp(USER, 86, 45, 1, 1, 0);

        vm.prank(USER);
        eProp.submitBuyer(USER2, 0, SELL_PRICE);

        vm.expectRevert(EProp.EProp__TokenNotForSaleForThisAddressOrListed.selector);
        hoax(USER2, 2 ether);
        eProp.payForToken{value: SELL_PRICE}(1);
    }

    function testPayForTokenRevertWhenNotPaidEnough() public {
        eProp.mintProp(USER, 44, 65, 1, 1, 0);

        vm.prank(USER);
        eProp.submitBuyer(USER2, 0, SELL_PRICE);

        vm.expectRevert(EProp.EProp__PaidAmountIsNotEnough.selector);
        hoax(USER2, 2 ether);
        eProp.payForToken{value: SELL_PRICE - 1000}(0);
    }

    function testMakeOffer() public {
        eProp.mintProp(USER, 44, 65, 1, 1, 0);

        vm.prank(USER2);
        eProp.makeOffer(0, 1 ether);

        vm.prank(address(3));
        eProp.makeOffer(0, 2 ether);

        vm.prank(USER);
        EProp.Offer[] memory offers = eProp.getOffers(0);

        assert(offers[0].sender == USER2);
        assert(offers[0].offerdAmount == 1 ether);
        assert(offers[1].sender == address(3));
        assert(offers[1].offerdAmount == 2 ether);
    }

    function testMakeOfferRevertWhenAlreadyOnSale() public {
        eProp.mintProp(USER, 44, 65, 1, 1, 0);
        vm.prank(USER);
        eProp.listTokenForSale(0, SELL_PRICE);

        vm.prank(USER2);
        vm.expectRevert(EProp.EProp__TokenAlreadyInSaleOrAuction.selector);
        eProp.makeOffer(0, 1 ether);
    }

    function testMakeOfferRevertWhenTokenNotExist() public {
        vm.prank(USER2);
        vm.expectRevert(EProp.EProp__WrongTokenIdEntered.selector);
        eProp.makeOffer(0, 1 ether);
    }

    function testMakeOfferRevertWhenOwnerOffers() public {
        eProp.mintProp(USER, 44, 65, 1, 1, 0);
        vm.prank(USER);
        eProp.listTokenForSale(0, SELL_PRICE);

        vm.prank(USER);
        vm.expectRevert(EProp.EProp__WrongTokenIdEntered.selector);
        eProp.makeOffer(0, 1 ether);
    }

    function testAcceptOffer() public {
        eProp.mintProp(USER, 44, 65, 1, 1, 0);

        vm.prank(USER2);
        eProp.makeOffer(0, 1 ether);

        vm.expectRevert(EProp.EProp__NotTokenOwnerOrApproved.selector);
        vm.prank(USER2);
        eProp.acceptOffer(0, 0);

        vm.prank(USER);
        eProp.acceptOffer(0, 0);

        vm.prank(USER);
        address buyer = eProp.getBuyer(0);

        vm.prank(USER);
        uint256 price = eProp.getTokenPrice(0);

        assert(price == 1 ether);
        assert(buyer == USER2);
    }

    function testGetTokenPriceRevertWhenNotBuyer() public {
        eProp.mintProp(USER, 44, 65, 1, 1, 0);

        vm.prank(USER);
        eProp.submitBuyer(USER2, 0, SELL_PRICE);

        vm.expectRevert(EProp.EProp__TokenNotForSaleForThisAddressOrListed.selector);
        eProp.getTokenPrice(0);
    }

    function testUriParts() public view {
        string memory length = "5";
        string memory width = "10";
        string memory location = string.concat('{"X": ', "1000", ' , "Y": ', "2000", "}");
        string memory propType = "APARTMENT";
        console.log(
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        abi.encodePacked(
                            '{"name":"',
                            "Eprop",
                            '","description":"EProp is a decentralized property ownership system.","attributes":[{"Length":"',
                            length,
                            '","Width":"',
                            width,
                            '","Location":"',
                            location,
                            '","Property type":"',
                            propType,
                            '"}],"image":"',
                            "https://ipfs.io/ipfs/QmVQfqv5YNXL73ypG125BBsooWRiVubF5nm2g9tRtPtyx8",
                            '"}'
                        )
                    )
                )
            )
        );
    }
}
