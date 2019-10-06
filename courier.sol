pragma solidity^0.5.0;

contract Courier {
    enum PackageStatus {
        inTransit,
        received,
        cancelled,
        arrived,
        booked
    }
    
    struct Package {
        uint id;
        uint weight;
        address sender;
        PackageStatus status;
        address receiver;
    }
    uint MULTIPLIER = 1;
    mapping (uint => address payable) public packageCourierId;
    mapping (address => uint) public pendingDeliveryCharge;
    Package[] private _packages;
    event PackageBooked(uint id, address sender, address receiver, uint weight);
    event PackagePicked(uint id, address courier, address sender, address receiver);
    event PackageArrived(uint id, address courier, address sender, address receiver);
    event PackageReceived(uint id, address courier, address sender, address receiver);
    event PackageCancelled(uint id, address courier, address sender, address receiver);
    
    function addPackage(uint  _weight, address payable receiver) public payable returns (uint){
        // Multipler is the numerical factor converting weight to delivery charge 
        // we are keeping it as 1 for now.  Value must be equal to
        // weight*MULTIPLIER
        
        require(msg.value == _weight*MULTIPLIER, "Incorrect amount");
        
        uint id = _packages.length;
        _packages.push(Package({
            id: id,
            weight: _weight,
            sender: msg.sender,
            status: PackageStatus.booked,
            receiver: receiver
        }));
        
        
        
        emit PackageBooked(id, msg.sender, receiver, _weight);
        pendingDeliveryCharge[msg.sender] += msg.value;
        
        return id;
        
    }
    
    function pickPackage(uint _id) public{
        // courier calls this function to indicate that he has picked up the package
        Package storage currentPackage = _packages[_id];
        require(currentPackage.status == PackageStatus.booked, "Package is already dispatched");
        currentPackage.status = PackageStatus.inTransit;
        
        packageCourierId[_id] = msg.sender;

        emit PackagePicked(_id, msg.sender, currentPackage.sender, currentPackage.receiver);
    
    }
    
    function arrivedPackage(uint _id) public{
        // this function will be called by the courier
        // to indicate to the receiver that he has arrived at his address
        
        Package storage currentPackage = _packages[_id];
        require(currentPackage.status == PackageStatus.inTransit, "Package was not in transit for it to arrive");
        currentPackage.status = PackageStatus.arrived;
        
        emit PackageArrived(_id, msg.sender, currentPackage.sender, currentPackage.receiver);
    }
    
    function receivedPackage(uint _id) public payable returns (bool){
        // this function will be called by the receiver
        // to indicate that he has received the package
        
        
        Package storage currentPackage = _packages[_id];
        
        require(currentPackage.receiver == msg.sender && currentPackage.status == PackageStatus.arrived, "Package arrived at wrong receiver");
        currentPackage.status = PackageStatus.received;
        uint deliveryCharge = currentPackage.weight*MULTIPLIER;
        address payable courier = packageCourierId[_id];

        
        if(courier.send(deliveryCharge)){
            pendingDeliveryCharge[currentPackage.sender] -= deliveryCharge;
            emit PackageReceived(_id, courier, currentPackage.sender, currentPackage.receiver);
            return true;
        }
        else {
            return false;
        }
    }
    
    function cancelPackage(uint _id) public returns (bool){
        // only sender of package has the right to cancel Package
        // Funds will be given to courier only if he has picked up the package
        Package storage currentPackage = _packages[_id];
        require(msg.sender == currentPackage.sender && (currentPackage.status == PackageStatus.inTransit || currentPackage.status == PackageStatus.booked), "You do not have authorization to cancel package");
        uint deliveryCharge = currentPackage.weight*MULTIPLIER;
        address payable courier = packageCourierId[_id];
        
        
        if (currentPackage.status == PackageStatus.inTransit){
            if (courier.send(deliveryCharge)){
                currentPackage.status = PackageStatus.cancelled;
                pendingDeliveryCharge[currentPackage.sender] -= deliveryCharge;
                emit PackageCancelled(_id, courier, currentPackage.sender, currentPackage.receiver);
                return true;
                
            }
            else {
                return false;
            }
            
        }
        
        currentPackage.status = PackageStatus.cancelled;
        return true;
    }
    
    
    
}