// SPDX-License-Identifier: GPL-3.0
/*
ABI findet sich im contracts ordner
*/
pragma solidity >=0.7.0 <0.9.0;

import "hardhat/console.sol";

contract streamingPayments {
    address public contractOwner; //contract owner
    uint public streamCount = 0; //counter vorhandener streams

    mapping(uint256 => Stream) public streams; //list of all streams

    constructor() {
      /*
      ausgelöst beim initialen deployment des contracts
      owner und pollcount anzahl werden hardcoded festgelegt
      */
        contractOwner = msg.sender;
        streamCount = 0;
    }

    /*
    struktur des Stream Objektes
    */
    struct Stream {
        address sender;
        address receiver;
        string streamName;
        uint256 start;
        uint256 end;
        uint256 toStream;
        uint256 amountSender;
        uint256 amountReceiver;
        bool cancelled;
        bool streamEnded;
        uint256 cancelledTime;
    }

    /*
    MODIFIER

    Modifier sind vordefinierte Regeln, werden im Funktionsheader als check eingebaut
    Nur wenn diese checks bestanden werden, wird die Funktion anschließend durchlaufen

    Modifier werden IMMER mit "_;" abgeschlossen!
    */

    //isOwner check
    modifier isOwner() {
        require(msg.sender == contractOwner, "Only owner perform this task");
        _;
    }

    //Ist der ausgewählte Stream aktiv?
    modifier streamActive(uint256 streamId) {
        require(
            block.timestamp >= streams[streamId].start,
            "The stream hasn't started yet!"
        );
        require(
            block.timestamp <= streams[streamId].end,
            "The stream is completed!"
        );
        require(
            streams[streamId].cancelledTime == 0,
            "The stream got cancelled!"
        );
        _;
    }

    //Ist der Stream noch aktiv?
    modifier streamEnded(uint256 streamId) {
        require(
            streams[streamId].streamEnded == true,
            "The stream hasn't ended yet!"
        );
        _;
    }

    //Ist Teilhaber eines bestimmten Streams
    modifier isParticipant(uint streamId, address addressToCheck) {
        require(
            streams[streamId].sender == addressToCheck || streams[streamId].receiver == addressToCheck,
            "You do not participate in this stream!"
        );
        _;
    }

    //Ist der Ersteller eines bestimmten Streams
    modifier isCreator(uint streamId, address addr) {
        require(streams[streamId].sender == addr, "Only stream creator can perform this task");
        _;
    }

    //Neuen Stream erstellen
    function newStream(string memory _name, address _receiver, uint256 _start, uint256 _end) public payable {
        Stream storage s = streams[streamCount];
        s.sender = msg.sender;
        s.receiver = _receiver;
        s.toStream = msg.value;
        s.amountSender = msg.value;
        s.amountReceiver = 0;
        s.streamName = _name;
        s.start = _start;
        s.end = _end;
        s.cancelled = false;
        s.streamEnded = false;
        s.cancelledTime = 0;

        increaseStreamCount();
    }

    //Bereits gestreamte Menge des Streams
    function streamedAmount(uint streamId) isParticipant(streamId, msg.sender) public view returns(uint256) {
        uint passedTime = block.timestamp - streams[streamId].start;
        uint totalTime = streams[streamId].end - streams[streamId].start;

        if (streams[streamId].cancelledTime != 0) {
            passedTime = streams[streamId].cancelledTime - streams[streamId].start;
        }

        if (passedTime < totalTime) {
            return (streams[streamId].toStream/totalTime) * passedTime;
        }
        else {
            return streams[streamId].toStream;
        }
    }

    //gibt des aktuellen Timestamp des Blocks als Ergebnis
    function blockTime() public view returns (uint256) {
        return block.timestamp;
    }

    //erhöht die Anzahl des Stream Counters
    function increaseStreamCount() internal {
        streamCount += 1;
    }

    //verringert die Anzahl des Stream Counters
    /*
    *Hint: gibt keine Funktion im Smart Contract, welcher eine Poll löschen kann
    */
    function decreaseStreamCount() internal {
        streamCount -= 1;
    }

    //Bricht einen aktiven Stream ab und verteilt die bereits gesamte Menge des Streams zwischen Sender und Empfänger nach dem Schlüssel der bereits vergangenen Zeit
    function cancelStream(uint streamId) isParticipant(streamId, msg.sender) streamActive(streamId) public returns (bool){
        streams[streamId].cancelledTime = block.timestamp;
        streams[streamId].cancelled = true;
        streams[streamId].streamEnded = true;

        uint totalTime = streams[streamId].end - streams[streamId].start;

        uint passedBeforeCancel = streams[streamId].cancelledTime - streams[streamId].start;
        uint amountStreamed = streams[streamId].toStream - ((streams[streamId].toStream/totalTime) * passedBeforeCancel);

        streams[streamId].amountReceiver = amountStreamed;
        streams[streamId].amountSender = streams[streamId].toStream - amountStreamed;

        return true;
    }

    //Auszahlen von Ether von dem Stream
    function withdrawEthFromStream(uint streamId) isParticipant(streamId, msg.sender) public returns (bool){
        if (streams[streamId].streamEnded == false) {
            if (block.timestamp >= streams[streamId].end) {
                streams[streamId].streamEnded = true;

                streams[streamId].amountSender = 0;
                streams[streamId].amountReceiver = streams[streamId].toStream;
            }
            else {
                return false;
            }
        }

        uint withdrawAmount = 0;

        if (msg.sender == streams[streamId].sender) {
            withdrawAmount = streams[streamId].amountSender;
            streams[streamId].amountSender = 0;
        }
        else if (msg.sender == streams[streamId].receiver) {
            withdrawAmount = streams[streamId].amountReceiver;
            streams[streamId].amountReceiver = 0;
        }

        payable(msg.sender).transfer(withdrawAmount);

        return true;
    }

    //Gibt alles IDs von Streams zurück, welche eine spezielle Addresse als sender hat
    /*
    *Hint: Für ein Smart Contract Array muss bekannt sein, wielange dieses Array ist; besitzt keine dynamische Länge
           Entsprechend wird einmal geloopt um die Länge des Array festzustellen
           Dann wird das Array mit dieser Länge erstellt
           Anschließend wird das längend definierte Array mit Werten in einer weiteren Loop befüllt
              IF Funktion zum feststellen der Länge und Befüllen ist die selbe
    */
    function allStreamsFromHolder(address addr) public view returns (uint[] memory)  {
        uint arrayLengthCounter = 0;

        for (uint i=0; i<streamCount; i++) {
            if (streams[i].sender == addr) {
                arrayLengthCounter++;
            }
        }

        uint[] memory streamsFromHolder = new uint[](arrayLengthCounter);
        uint arrayPositionCounter = 0;

        for (uint i=0; i<streamCount; i++) {
            if (streams[i].sender == addr) {
                streamsFromHolder[arrayPositionCounter] = i;
                arrayPositionCounter++;
            }
        }

        return streamsFromHolder;
    }

    //Gibt alles IDs von Streams zurück, welche eine spezielle Addresse als Empfänger hat
    /*
    *Hint: Für ein Smart Contract Array muss bekannt sein, wielange dieses Array ist; besitzt keine dynamische Länge
           Entsprechend wird einmal geloopt um die Länge des Array festzustellen
           Dann wird das Array mit dieser Länge erstellt
           Anschließend wird das längend definierte Array mit Werten in einer weiteren Loop befüllt
              IF Funktion zum feststellen der Länge und Befüllen ist die selbe
    */
    function allStreamsHolderParticipates(address addr) public view returns (uint[] memory)  {
        uint arrayLengthCounter = 0;

        for (uint i=0; i<streamCount; i++) {
            if (streams[i].receiver == addr) {
                arrayLengthCounter++;
            }
        }

        uint[] memory streamsFromHolder = new uint[](arrayLengthCounter);
        uint arrayPositionCounter = 0;

        for (uint i=0; i<streamCount; i++) {
            if (streams[i].receiver == addr) {
                streamsFromHolder[arrayPositionCounter] = i;
                arrayPositionCounter++;
            }
        }

        return streamsFromHolder;
    }
}
