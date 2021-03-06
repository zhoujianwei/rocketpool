pragma solidity ^0.4.8;

import "./RocketHub.sol";
import "./interface/RocketSettingsInterface.sol";
import "./interface/RocketPoolInterface.sol";
import "./contract/Owned.sol";


/// @title The Rocket Smart Node contract - more methods for nodes will be moved from RocketPool to here when metropolis is released
/// @author David Rugendyke

contract RocketNode is Owned {

    /**** Properties ***********/

    // Hub address
    address private rocketHubAddress;
    // The current version of this contract
    uint8 private version;
    // Miniumum balance a node must have to cover gas costs for smart node services when registered
    uint private minNodeWei;

              
    /*** Events ****************/

    event NodeRegistered (
        address indexed _nodeAddress,
        uint256 created
    );

    event NodeRemoved (
        address indexed _address,
        uint256 created
    );
   

    /*** Modifiers *************/


    /// @dev Only allow access from the latest version of the RocketPool contract
    modifier onlyLatestRocketPool() {
        RocketHub rocketHub = RocketHub(rocketHubAddress);
        if (msg.sender != rocketHub.getRocketPoolAddress()) throw;
        _;
    }

    
    /*** Methods *************/
   
    /// @dev pool constructor
    function RocketNode(address deployedRocketHubAddress) {
        // Set the address of the main hub
        rocketHubAddress = deployedRocketHubAddress;
        // Set the min eth needed for a node account to cover gas costs
        minNodeWei = 5 ether;
    }


    /// @dev Set the min eth required for a node to be registered
    /// @param amountInWei The amount in Wei
    function setMinNodeWei(uint amountInWei) public onlyOwner  {
        minNodeWei = amountInWei;
    }


    /// @dev Get an available node for a pool to be assigned too
    // TODO: As well as assigning pools by node user server load, assign by node geographic region to aid in redundancy and decentralisation 
    function nodeAvailableForPool() public onlyLatestRocketPool returns(address) {
        // This is called only by registered Rocket mini pools 
        RocketHub rocketHub = RocketHub(rocketHubAddress);
        // Get all the current registered nodes
        uint256 nodeCount = rocketHub.getRocketNodeCount();
        // Create an array at the length of the current nodes, then populate it
        // This step would be infinitely easier and efficient if you could return variable arrays from external calls in solidity
        address[] memory nodes = new address[](nodeCount);
        address nodeAddressToUse = 0;
        uint256 prevAverageLoad = 0;
        // Retreive each node address now by index since we can't return a variable sized array from an external contract yet
        if(nodes.length > 0) {
            for(uint32 i = 0; i < nodes.length; i++) {
                // Get our node address
                address currentNodeAddress = rocketHub.getRocketNodeByIndex(i);
                // Get the node details
                uint256 averageLoad =  rocketHub.getRocketNodeAverageLoad(currentNodeAddress);
                bool active =  rocketHub.getRocketNodeActive(currentNodeAddress);
                // Get the node with the lowest current work load average to help load balancing and avoid assigning to any servers currently not activated
                // A node must also have checked in at least once before being assinged, hence why the averageLoad must be greater than zero
                nodeAddressToUse = (averageLoad <= prevAverageLoad || i == 0) && averageLoad > 0  && active == true ? currentNodeAddress : nodeAddressToUse;
                prevAverageLoad = averageLoad;
            }
            // We have an address to use, excellent, assign it
            if(nodeAddressToUse != 0) {
                return nodeAddressToUse;
            }
        }
        // No registered nodes yet
        throw; 
    } 


    /// @dev Register a new node address if it doesn't exist, only the contract creator can do this
    /// @param nodeAccountAddressToRegister New nodes coinbase address
    function nodeRegister(address nodeAccountAddressToRegister, string oracleID, string instanceID) public onlyOwner  {
        // Get the balance of the node, must meet the min requirements to service gas costs for checkins, oracle services etc
        if(nodeAccountAddressToRegister.balance >= minNodeWei) {
            // Add the node to the primary persistent storage so any contract upgrades won't effect the current stored nodes
            RocketHub rocketHub = RocketHub(rocketHubAddress);
            // Sets the rocket node if the address is ok and isn't already set
            if(rocketHub.setRocketNode(nodeAccountAddressToRegister, sha3(oracleID), sha3(instanceID))) {
                // Fire the event
                NodeRegistered(nodeAccountAddressToRegister, now);
            }
        }else{
            throw;
        }
	}


    /// @dev Owner can manually activate or deactivate a node, this will stop the node accepting new pools to be assigned to it
    /// @param nodeAddress Address of the node
    /// @param activeStatus The status to set the node
    function nodeSetActiveStatus(address nodeAddress, bool activeStatus) public onlyOwner {
        // Get our RocketHub contract with the node storage, so we can check the node is legit
        RocketHub rocketHub = RocketHub(rocketHubAddress);
        rocketHub.setRocketNodeActive(nodeAddress, activeStatus);
    }


    /// @dev Remove a node from the Rocket Pool network
    function nodeRemove(address nodeAddress) public onlyOwner {
        // Get the hub
        RocketHub rocketHub = RocketHub(rocketHubAddress);
        RocketPoolInterface rocketPool = RocketPoolInterface(rocketHub.getRocketPoolAddress());
        // Check the node doesn't currently have any registered mini pools associated with it
        if(rocketPool.getPoolsFilterWithNodeCount(nodeAddress) == 0) {
            // Sets the rocket partner if the address is ok and isn't already set
            if(rocketHub.setRocketNodeRemove(nodeAddress)) {
                // Fire the event
                NodeRemoved(nodeAddress, now);
            }
        }else{
            throw;
        }
    } 


}
