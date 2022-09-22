// SPDX-License-Identifier: GPL-3.0
/*
ABI findet sich im contracts ordner
*/
pragma solidity >=0.7.0 <0.9.0;

import "hardhat/console.sol";

contract Voting {
    address public contractOwner; //contract owner
    uint public pollCount = 0; //counter vorhandener polls

    mapping(uint256 => Poll) public polls; //list of all polls

    constructor() {
      /*
      ausgelöst beim initialen deployment des contracts
      owner und pollcount anzahl werden hardcoded festgelegt
      */
        contractOwner = msg.sender;
        pollCount = 0;
    }

    /*
    struktur des Voter Objektes
    */
    struct Voter {
        address addr;
        bool voted;
        bool vote;
    }

    /*
    struktur des Poll Objektes
    */
    struct Poll {
        address creator;
        string name;
        string question;
        uint256 yes;
        uint256 no;
        uint256 start;
        uint256 end;
        mapping(address => Voter) voters;
        mapping(address => bool) registered;
        address[] voterIndices;
        uint voterCount;
    }

    /*
    MODIFER

    Modifier sind vordefinierte Regeln, werden im Funktionsheader als check eingebaut
    Nur wenn diese checks bestanden werden, wird die Funktion anschließend durchlaufen

    Modifier werden IMMER mit "_;" abgeschlossen!
    */

    //isOwner check
    modifier isOwner() {
        require(msg.sender == contractOwner, "Only owner perform this task");
        _;
    }

    //Darf diese Addresse voten
    modifier allowedVoter(uint256 pollNumber, address addr) {
        require(polls[pollNumber].registered[addr] == true, "You need to be registered for this poll!");

        require(polls[pollNumber].voters[addr].voted == false, "You can only vote once!");
        _;
    }

    //Ist die Poll zum voten noch aktiv?
    modifier pollActive(uint256 pollNumber) {
        require(
            block.timestamp >= polls[pollNumber].start,
            "The poll hasn't started yet!"
        );
        require(
            block.timestamp <= polls[pollNumber].end,
            "The poll is already over!"
        );
        _;
    }

    //Ist der Caller der Creater der Poll?
    modifier isCreator(uint pollNumber, address addr) {
        require(polls[pollNumber].creator == addr, "Only poll creator can perform this task");
        _;
    }

    //Neue Poll erstellen
    function newPoll(string memory _name, string memory _question, uint256 _start, uint256 _end) public {
        Poll storage p = polls[pollCount];
        p.name = _name;
        p.question = _question;
        p.creator = msg.sender;
        p.start = _start;
        p.end = _end;
        p.yes = 0;
        p.no = 0;
        p.registered[msg.sender] = true;

        Voter storage voter = polls[pollCount].voters[msg.sender];
        voter.addr = msg.sender;
        voter.voted = false;
        voter.vote = false;

        p.voters[msg.sender] = voter;
        p.voterIndices.push(msg.sender);
        p.voterCount = 1;

        increasePoll();
    }

    //gibt des aktuellen Timestamp des Blocks als Ergebnis
    function blockTime() public view returns (uint256) {
        return block.timestamp;
    }

    //Funktion um für eine Poll zu voten
    function votePoll(uint256 pollNumber, bool vote)
        public
        allowedVoter(pollNumber, msg.sender)
        pollActive(pollNumber)
    {
        Poll storage p = polls[pollNumber];

        if (vote == true) {
            p.yes += 1;
            polls[pollNumber].voters[msg.sender].vote = true;
        } else {
            p.no += 1;
            p.voters[msg.sender].vote = false;
        }

        p.voters[msg.sender].voted = true;

    }

    //Löschen eines Voters von einer Poll
    /*
    Falls der Voter schon gevotet hat, muss dieser Vote von der Poll abgezogen werden
    */
    function deleteVoter(uint256 pollNumber, address addr) internal{
        for(uint256 i=0;i<polls[pollNumber].voterCount;i++){
            if(polls[pollNumber].voterIndices[i] == addr){
                polls[pollNumber].voterIndices[i] = polls[pollNumber].voterIndices[polls[pollNumber].voterIndices.length-1];
                polls[pollNumber].voterIndices.pop();
                if(polls[pollNumber].voters[addr].voted == true){
                    if(polls[pollNumber].voters[addr].vote == false){
                        polls[pollNumber].no--;
                    }
                    else if(polls[pollNumber].voters[addr].vote == true){
                        polls[pollNumber].yes--;
                    }
                }
            }
        }
        delete polls[pollNumber].voters[addr];
        delete polls[pollNumber].registered[addr];
    }

    //Voter für Poll anmelden
    function registerVoter(uint pollNumber, address toRegistrate) public isCreator(pollNumber, msg.sender) {
        require(
            alreadyRegistered(pollNumber, toRegistrate) == false,
            "Voter already registered!"
        );

        polls[pollNumber].registered[toRegistrate] = true;
        polls[pollNumber].voterIndices.push(toRegistrate);
        polls[pollNumber].voters[toRegistrate] = Voter({addr: toRegistrate, voted: false, vote:false});
        polls[pollNumber].voterCount++;
    }

    //Voter von Poll abmelden
    function unregisterVoter(uint pollNumber, address toUnregistrate) public isCreator(pollNumber, msg.sender) {
        require(
            alreadyRegistered(pollNumber, toUnregistrate) == true,
            "Voter is not registered!"
        );

        deleteVoter(pollNumber, toUnregistrate);
        polls[pollNumber].voterCount--;
    }

    //Poll Count erhöhen, wenn eine erstellt wird
    function increasePoll() internal {
        pollCount += 1;
    }

    //Poll Count verringernm, wenn eine Poll gelöscht wird
    /*
    *Hint: gibt keine Funktion im Smart Contract, welcher eine Poll löschen kann
    */
    function decreasePoll() internal {
        pollCount -= 1;
    }

    //Ist die Addresse bereits registriert?
    function alreadyRegistered(uint pollNumber, address toRegistrate)
        internal
        view
        returns (bool)
    {
        if (polls[pollNumber].registered[toRegistrate] == true) {
            return true;
        }
        return false;
    }

    //Gibt alles IDs von Polls zurück, welche eine spezielle Addresse erstellt hat
    /*
    *Hint: Für ein Smart Contract Array muss bekannt sein, wielange dieses Array ist; besitzt keine dynamische Länge
           Entsprechend wird einmal geloopt um die Länge des Array festzustellen
           Dann wird das Array mit dieser Länge erstellt
           Anschließend wird das längend definierte Array mit Werten in einer weiteren Loop befüllt
              IF Funktion zum feststellen der Länge und Befüllen ist die selbe
    */
    function allPollsFromHolder(address addr) public view returns (uint[] memory)  {
        uint arrayLengthCounter = 0;

        for (uint i=0; i<pollCount; i++) {
            if (polls[i].creator == addr) {
                arrayLengthCounter++;
            }
        }

        uint[] memory pollsFromHolder = new uint[](arrayLengthCounter);
        uint arrayPositionCounter = 0;

        for (uint i=0; i<pollCount; i++) {
            if (polls[i].creator == addr) {
                pollsFromHolder[arrayPositionCounter] = i;
                arrayPositionCounter++;
            }
        }

        return pollsFromHolder;
    }

    //Wieviele haben bereits für die Poll gevotet
    function getVoterCount(uint pollId) public view returns (uint){
        return polls[pollId].voterCount;
    }

    //Gibt alle IDs von Polls zurück, welche eine spezielle Addresse als Voter registriert ist
    /*
    *Hint: Für ein Smart Contract Array muss bekannt sein, wielange dieses Array ist; besitzt keine dynamische Länge
           Entsprechend wird einmal geloopt um die Länge des Array festzustellen
           Dann wird das Array mit dieser Länge erstellt
           Anschließend wird das längend definierte Array mit Werten in einer weiteren Loop befüllt
              IF Funktion zum feststellen der Länge und Befüllen ist die selbe
    */
    function allPollsHolderParticipates(address addr) public view returns (uint[] memory)  {
        uint arrayLengthCounter = 0;

        for (uint i=0; i<pollCount; i++) {
            for (uint j=0; j<polls[i].voterCount; j++) {
                if (polls[i].voterIndices[j] == addr) {
                    arrayLengthCounter++;
                }
            }
        }

        uint[] memory pollsFromHolder = new uint[](arrayLengthCounter);
        uint arrayPositionCounter = 0;

        for (uint i=0; i<pollCount; i++) {
            for (uint j=0; j<polls[i].voterCount; j++) {
                if (polls[i].voterIndices[j] == addr) {
                    pollsFromHolder[arrayPositionCounter] = i;
                    arrayPositionCounter++;
                }
            }
        }

        return pollsFromHolder;
    }
}
