// SPDX-License-Identifier: GPL-3.0
/*
ABI findet sich im contracts ordner
*/
pragma solidity >=0.7.0 <0.9.0;

import "hardhat/console.sol";

contract WeightedDistribution {

    address public contractOwner; //contract owner
    uint public shareCount = 0; //counter vorhandener polls
    uint internal shareIDvar = 0; //idvar vorhandener polls

    mapping(uint => Share) public allShares; //list of all shares

    constructor() {
      /*
      ausgelöst beim initialen deployment des contracts
      owner shareIdVar und shareCount anzahl werden hardcoded festgelegt
      */
        contractOwner = msg.sender;
        shareCount = 0;
        shareIDvar = 0;
    }

    /*
    struktur des Shareholder Objektes
    */
    struct Shareholder {
        address addr;
        bool active;
        uint balance;
        uint totalRewards;
        uint withdrawable;
    }

    /*
    struktur des Share Objektes
    */
    struct Share {
        address creator;
        string name;
        uint transferCount;
        uint totalSupply;
        uint holderIDvar;
        mapping(address => Shareholder) shareholders; // Map containing all registered holders for share
        address[] holderIndices; // helper-array to loop through all holder quickly
        uint holderCount;
    }

    /*
    MODIFER

    Modifier sind vordefinierte Regeln, werden im Funktionsheader als check eingebaut
    Nur wenn diese checks bestanden werden, wird die Funktion anschließend durchlaufen

    Modifier werden IMMER mit "_;" abgeschlossen!
    */

    //isOwner check
    modifier isContractOwner() {
        require(msg.sender == contractOwner, "Only owner can perform this task");
        _;
    }

    //isRegistered check
    modifier isRegistered(uint shareID, address addr) {
        console.log(allShares[shareID].shareholders[addr].active);
        require(allShares[shareID].shareholders[addr].active, "You are not registered!");
        _;
    }

    //isShareCreator check
    modifier isShareCreator(uint shareID) {
        require(allShares[shareID].creator == msg.sender, "Only the creator of this share is eligible to perform this task!");
        _;
    }

    //Ist wert positiv
    modifier isPositive(uint num){
        require(num > 0, "Value must be greater than '0'");
        _;
    }

    //Ist shareholder
    modifier isShareholder(uint shareID, address addr) {
        require(allShares[shareID].shareholders[addr].active, "Given address has no holdings of this share or is inactive!");
        _;
    }

    //Besitzt genug Holdings
    modifier hasEnough(uint shareID, uint amount){
        require(allShares[shareID].shareholders[msg.sender].balance >= amount, "You dont have enough holdings!");
        _;
    }

    //Shareholder hat noch immer Holdings
    modifier hasNoHoldings(uint shareID, address addr){
        require(allShares[shareID].shareholders[addr].balance == 0, "The Shareholder you tried to delete still has holdings left");
        _;
    }

    //Passt die entnahmemenge
    modifier canWithdrawAmount(uint shareID, uint amount) {
        require(allShares[shareID].shareholders[msg.sender].withdrawable >= amount, "Your withdraw amount is too high");
        _;
    }

    //Rest nach entnahme ist noch positiv
    modifier canWithdrawZero(uint shareID, uint amount) {
        require((allShares[shareID].shareholders[msg.sender].withdrawable - amount) > 0, "Your withdraw amount is too high");
        _;
    }

    //Erstellen eine neuen Share
    function createShare(string memory _name, uint _supply) public {
        Share storage share = allShares[shareIDvar];
        share.creator = msg.sender;
        share.name = _name;
        share.transferCount = 0;
        share.totalSupply = _supply;
        share.holderIDvar = 1;

        Shareholder storage shareholder = allShares[shareIDvar++].shareholders[msg.sender];
        shareholder.addr = msg.sender;
        shareholder.active = true;
        shareholder.balance = _supply;
        share.shareholders[msg.sender] = shareholder;
        share.holderIndices.push(msg.sender);
        share.holderCount = 1;

        shareCount++;
        console.log("Share Created!");
    }

    //Gibt die Balance von einer bestimmten Addresse aus
    function getBalanceOf(uint shareID, address addr) public view returns(uint){
        return allShares[shareID].shareholders[addr].balance;
    }

    //registriert einen Shareholder zu einer gewissen Sahre
    function registerShareholder(uint shareID, address toRegister) public isShareCreator(shareID) {
        require(alreadyRegistered(shareID, toRegister) == false, "Voter already registered!");

        createShareholder(shareID, toRegister);
        allShares[shareID].holderCount++;
    }

    //Entfernt eine Shareholder von einer gewissen Share
    function unregisterShareholder(uint shareID, address toUnregister) public isShareCreator(shareID) isShareholder(shareID, toUnregister) hasNoHoldings(shareID, toUnregister) {
        require(alreadyRegistered(shareID, toUnregister) == true, "Voter not found in registry");

        deleteShareholder(shareID, toUnregister);
        allShares[shareID].holderCount--;
    }

    //Transferieren von Holdings
    function transferShareHoldings(uint shareID, uint amount, address destinationShareholder) public isRegistered(shareID, msg.sender) isRegistered(shareID, destinationShareholder) isPositive(amount) hasEnough(shareID, amount){
        console.log("starting transfer");
        allShares[shareID].shareholders[msg.sender].balance -= amount;
        allShares[shareID].shareholders[destinationShareholder].balance += amount;
        allShares[shareID].transferCount++;
    }

    //Menge an Rewards welche eine Shareholder hat
    function rewardShareholder(uint shareID, uint reward) public isShareCreator(shareID) returns (uint[] memory){
        uint[] memory rewards = new uint[](allShares[shareID].holderCount);
        for(uint i =0; i< allShares[shareID].holderCount;i++){
            allShares[shareID].shareholders[allShares[shareID].holderIndices[i]].totalRewards += allShares[shareID].shareholders[allShares[shareID].holderIndices[i]].balance * reward / allShares[shareID].totalSupply;
            rewards[i] = allShares[shareID].shareholders[allShares[shareID].holderIndices[i]].totalRewards;
        }
        return rewards;
    }

    //Menge an Rewards eines Shareholders in ETH
    function rewardShareholderEth(uint shareID) public payable returns (bool){
        uint reward = msg.value;

        for (uint i=0; i<allShares[shareID].holderCount; i++) {
            allShares[shareID].shareholders[allShares[shareID].holderIndices[i]].totalRewards += allShares[shareID].shareholders[allShares[shareID].holderIndices[i]].balance * reward / allShares[shareID].totalSupply;
            allShares[shareID].shareholders[allShares[shareID].holderIndices[i]].withdrawable += allShares[shareID].shareholders[allShares[shareID].holderIndices[i]].balance * reward / allShares[shareID].totalSupply;
        }

        return true;
    }

    //Gibt aktuelle Balance aus
    function getBalance() public view returns(uint) {
        return address(this).balance;
    }

    //Zalht ETH an shareholder aus
    function withdrawEthShareholder(uint shareID) public returns (bool){
        uint withdrawAmount = allShares[shareID].shareholders[msg.sender].withdrawable;
        allShares[shareID].shareholders[msg.sender].withdrawable = 0;
        payable(msg.sender).transfer(withdrawAmount);

        return true;
    }

    //Gesamten Rewards eines Shareholders über alle Shares verteitl
    function sumAllRewardsOfHolder(address addr) public view returns (uint){
        uint summedRewards = 0;
        for(uint i=0; i<shareIDvar; i++) {
            summedRewards += allShares[i].shareholders[addr].totalRewards;
            //rewards += allShares[i].shareholders[allShares[shareID].holderIndices[i]].totalRewards += allShares[shareID].shareholders[allShares[shareID].holderIndices[i]].balance * reward / allShares[shareID].totalSupply;
        }
        return summedRewards;
    }

    //SUmme die Ausgezahlt werden kann von iener bestimmten Share, einer bestimmten Addresse
    function sumWithdrawableOfHolderFromShare(uint shareID, address addr) public view returns (uint) {
        return allShares[shareID].shareholders[addr].withdrawable;
    }

    //Erstellt shareholder für eine Share
    function createShareholder(uint shareID, address addr) internal{
        Shareholder memory s = Shareholder(addr, true, 0, 0, 0);
        allShares[shareID].holderIndices.push(addr);
        allShares[shareID].shareholders[addr] = s;
    }

    //Entfernt shareholder von einer share
    function deleteShareholder(uint shareID, address addr) internal{
        delete allShares[shareID].shareholders[addr];
        // delete shareDistribution[addr];
        for(uint i=0;i<allShares[shareID].holderCount;i++){
            if(allShares[shareID].holderIndices[i] == addr){
                allShares[shareID].holderIndices[i] = allShares[shareID].holderIndices[allShares[shareID].holderIndices.length-1];
                allShares[shareID].holderIndices.pop();
            }
        }
    }

    //Gibt alles IDs von Shares zurück, welche eine spezielle Addresse erstellt hat
    /*
    *Hint: Für ein Smart Contract Array muss bekannt sein, wielange dieses Array ist; besitzt keine dynamische Länge
           Entsprechend wird einmal geloopt um die Länge des Array festzustellen
           Dann wird das Array mit dieser Länge erstellt
           Anschließend wird das längend definierte Array mit Werten in einer weiteren Loop befüllt
              IF Funktion zum feststellen der Länge und Befüllen ist die selbe
    */
    function allSharesFromHolder(address addr) public view returns (uint[] memory)  {
        uint arrayLengthCounter = 0;

        for (uint i=0; i<shareIDvar; i++) {
            if (allShares[i].creator == addr) {
                arrayLengthCounter++;
            }
        }

        uint[] memory sharesFromHolder = new uint[](arrayLengthCounter);
        uint arrayPositionCounter = 0;

        for (uint i=0; i<shareIDvar; i++) {
            if (allShares[i].creator == addr) {
                sharesFromHolder[arrayPositionCounter] = i;
                arrayPositionCounter++;
            }
        }

        return sharesFromHolder;
    }

    //Gibt alle IDs von Shares zurück, welche eine spezielle Addresse als Shareholder registriert ist
    /*
    *Hint: Für ein Smart Contract Array muss bekannt sein, wielange dieses Array ist; besitzt keine dynamische Länge
           Entsprechend wird einmal geloopt um die Länge des Array festzustellen
           Dann wird das Array mit dieser Länge erstellt
           Anschließend wird das längend definierte Array mit Werten in einer weiteren Loop befüllt
              IF Funktion zum feststellen der Länge und Befüllen ist die selbe
    */
    function allSharesHolderParticipates(address addr) public view returns (uint[] memory)  {
        uint arrayLengthCounter = 0;

        for (uint i=0; i<shareIDvar; i++) {
            for (uint j=0; j<allShares[i].holderCount; j++) {
                if (allShares[i].holderIndices[j] == addr) {
                    arrayLengthCounter++;
                }
            }
        }

        uint[] memory sharesFromHolder = new uint[](arrayLengthCounter);
        uint arrayPositionCounter = 0;

        for (uint i=0; i<shareIDvar; i++) {
            for (uint j=0; j<allShares[i].holderCount; j++) {
                if (allShares[i].holderIndices[j] == addr) {
                    sharesFromHolder[arrayPositionCounter] = i;
                    arrayPositionCounter++;
                }
            }
        }

        return sharesFromHolder;
    }

    //Check ob eine addresse bereits bei einer Share registriert ist
    function alreadyRegistered(uint shareID, address addr) internal view returns(bool) {
        if (allShares[shareID].shareholders[addr].active) {
            return true;
        }
        return false;
    }
}
