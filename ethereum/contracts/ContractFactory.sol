pragma solidity ^0.4.26;
pragma experimental ABIEncoderV2;
import './SupplyTrack.sol';

contract QualityCertifier {
    function verifyRequest(address, string) public pure returns(uint) { }
}

contract ContractFactory {

    // struct Request {
    //     string productName;
    //     string universalProductCode;
    //     string productDescription;
    //     uint perBatchQuantity;
    //     uint totalBatches;
    //     string[] batchIds;
    //     bool certificationStatus;
    //     string requestStatus;
    //     uint pricePerBatch;
    // }

    struct Actor {
        string name;
        mapping(string => uint) productionLimits;
        mapping(string => bool) isCertified;
        bool presence;
    }

    // event actorDataUpdated(string _name, string _universalProductCode, bool _isCertified, uint _productionLimit);

    address public committeeAddress;
    address public certifierAddress;
    mapping(address => address[]) private deployedContracts;
    // mapping(address => Request[]) public requestLog;
    mapping(address => Actor) public actors;
    address[] private clients;
    QualityCertifier certifierInstance;

    constructor(address _certifierAddress) public {
        committeeAddress = msg.sender;
        certifierAddress = _certifierAddress;
        certifierInstance = QualityCertifier(_certifierAddress);
    }

    function getClients() public view returns(address[]) {
        return clients;
    }

    function getDeployedContracts(address producerAddress) public view returns(address[]) {
        return deployedContracts[producerAddress];
    }

    function getProductionLimit(address producerAddress, string universalProductCode) public view returns(uint) {
        return actors[producerAddress].productionLimits[universalProductCode];
    }

    function registerActor(address id, string name) public {
        require(msg.sender == committeeAddress, "Function only accessible to creator of this contract.");
        Actor memory newActor = Actor({
            name: name,
            presence: true
        });
        actors[id] = newActor;
        clients.push(id);
    }

    function processesRequest(
            string productName,
            string universalProductCode,
            string productDescription,
            uint perBatchQuantity,
            uint totalBatches,
            string[] batchIds,
            uint pricePerBatch
        ) public {

        address producerAddress = msg.sender;

        require(actors[producerAddress].presence, "Actor is not registered.");

        bool isCertified = actors[producerAddress].isCertified[universalProductCode];
        uint productionLimit = actors[producerAddress].productionLimits[universalProductCode];

        if(!isCertified) {
            productionLimit = certifierInstance.verifyRequest(producerAddress, universalProductCode);
            if(productionLimit > 0) {
                isCertified = true;
                actors[producerAddress].productionLimits[universalProductCode] = productionLimit;
                actors[producerAddress].isCertified[universalProductCode] = isCertified;
                // emit actorDataUpdated(
                //     actors[producerAddress].name,
                //     universalProductCode,
                //     isCertified,
                //     productionLimit
                // );
            }
        }

        uint requestedQuantity = perBatchQuantity*totalBatches;

        require(requestedQuantity <= productionLimit, "Production limit exhausted");

        productionLimit = productionLimit - requestedQuantity;
        actors[producerAddress].productionLimits[universalProductCode] = productionLimit;

        // Request memory newRequest = Request({
        //     productName: productName,
        //     universalProductCode: universalProductCode,
        //     productDescription: productDescription,
        //     perBatchQuantity: perBatchQuantity,
        //     totalBatches: totalBatches,
        //     batchIds: batchIds,
        //     certificationStatus: isCertified,
        //     requestStatus: "Accepted",
        //     pricePerBatch: pricePerBatch
        // });
        // requestLog[producerAddress].push(newRequest);

        address newTrackAddress = new SupplyTrack(
            actors[producerAddress].name,
            producerAddress,
            productName,
            universalProductCode,
            productDescription,
            perBatchQuantity,
            totalBatches,
            pricePerBatch,
            batchIds
        );
        deployedContracts[producerAddress].push(newTrackAddress);
    }
}