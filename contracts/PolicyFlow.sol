// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

import "./libraries/PolicyTypes.sol";
import "./libraries/ToStrings.sol";
import "./interfaces/IInsurancePool.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "./interfaces/IPolicyToken.sol";

/**
 * @title  PolicyFlow
 * @notice This is the policy flow contract which is responsible for the whole lifecycle of a policy.
 *         Every policy's information are stored in this contract.
 *         A policy will have a "_policyOrder" and a "_policyId":
 *
 *             policyOrder: The total order in this product. Should be equal to its ERC721 tokenId
 *             policyId: A bytes32 representation of a policy and it's unique
 *
 *         The main functions of a policy are: newApplication & newClaimRequest.
 *         We use Chainlink in this contract to get the final status of a flight.
 *
 *
 */
contract PolicyFlow is ChainlinkClient, PolicyTypes, ToStrings {
    using Chainlink for Chainlink.Request;
    using Strings for uint256;
    using ECDSA for bytes32;

    bytes32 internal _SUBMIT_CLAIM_TYPEHASH;

    uint256 public oracleResponse; // A test variable to store the oracle address
    uint256 fee;
    string private FLIGHT_STATUS_URL = "http://39.101.132.228:8000/live/";
    address private oracleAddress;
    bytes32 private jobId;

    mapping(bytes32 => uint256) requestList; // requestId => total order
    mapping(uint256 => uint256) resultList; // total order => delay result

    address public owner;
    IInsurancePool insurancePool;
    IPolicyToken policyToken;

    // Minimum time before departure for applying
    uint256 public MIN_TIME_BEFORE_DEPARTURE = 24 hours;
    uint256 public DELAY_THRESHOLD = 240;
    uint256 public Total_Policies;

    // Mappings
    mapping(bytes32 => PolicyInfo) policyList; // policyId => policyInfo
    mapping(uint256 => bytes32) policyOrderList; // total order => policyId

    mapping(address => uint256[]) userPolicy; // uint256[]: those totalOrders of a user
    mapping(address => uint256) userPolicyCount; // userAddress => user policy amount

    // Constructor Function
    constructor(
        IInsurancePool _insurancePool,
        IPolicyToken _policyToken,
        address _oracleAddress
    ) {
        // Set owner address
        owner = msg.sender;

        // Set two interfaces' addresses
        insurancePool = _insurancePool;
        policyToken = _policyToken;

        // Set oracle address
        oracleAddress = _oracleAddress;
        jobId = "cef74a7ff7ea4194ab97f00c89abef6b";

        setPublicChainlinkToken();
        fee = 1 * 10**18; // 1 LINK

        // Initialize the count (actually do not need to initialize)
        Total_Policies = 0;

        _SUBMIT_CLAIM_TYPEHASH = keccak256(
            "DegisSubmitClaim(uint256 policyOrder,uint256 amountOut,uint256 deadline)"
        );
    }

    // ************************************ Modifiers ************************************ //

    modifier onlyOracle() {
        require(
            msg.sender == oracleAddress,
            "only the oracle can call this function"
        );
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "only the owner can call this function");
        _;
    }

    /// *************************** ///
    ///        View Functions       ///
    /// *************************** ///

    /**
     * @notice Returns the address of the LINK token
     * @dev This is the public implementation for chainlinkTokenAddress, which is
     *      an internal method of the ChainlinkClient contract
     */
    function getChainlinkToken() public view returns (address) {
        return chainlinkTokenAddress();
    }

    /**
     * @notice Show a user's policies (all)
     * @param _userAddress: User's address (buyer)
     * @return User's policy details in string form
     */
    function viewPolicy(address _userAddress)
        public
        view
        returns (string memory)
    {
        require(userPolicyCount[_userAddress] > 0, "no policy for this user");

        uint256 policyCount = userPolicyCount[_userAddress];
        string memory result = " ";

        for (uint256 i = 0; i < policyCount; i++) {
            uint256 policyOrder = userPolicy[_userAddress][i];

            bytes32 policyid = policyOrderList[policyOrder];

            string memory isUsed = policyList[policyid].isUsed
                ? "used"
                : "not used";

            string memory result1 = encodePack1(
                i,
                policyList[policyid].flightNumber,
                policyid,
                policyList[policyid].productId,
                policyList[policyid].buyerAddress
            );
            string memory result2 = encodePack2(
                policyList[policyid].premium,
                policyList[policyid].payoff,
                policyList[policyid].purchaseDate,
                policyList[policyid].departureDate,
                policyList[policyid].landingDate,
                uint256(policyList[policyid].status),
                isUsed,
                policyList[policyid].delayResult
            );

            result = string(abi.encodePacked(result, result1, result2));
        }
        return result;
    }

    /**
     * @notice Get the policyId (bytes32) from its count/order
     * @param _count: Total count
     * @return PolicyId (bytes32)
     */
    function getPolicyIdByCount(uint256 _count) public view returns (bytes32) {
        return policyOrderList[_count];
    }

    /**
     * @notice Get the policyInfo from its count/order
     * @param _count: Total count of the policy
     */
    function getPolicyInfoByCount(uint256 _count)
        public
        view
        returns (
            string memory _flightNumber,
            bytes32 _policyId,
            uint256 _productId,
            address _owner,
            uint256 _premium,
            uint256 _payoff,
            uint256 _purchaseDate,
            uint256 _departureDate,
            uint256 _landingDate,
            uint256 _policyStatus
        )
    {
        bytes32 policyId = policyOrderList[_count];
        return (
            policyList[policyId].flightNumber,
            policyId,
            policyList[policyId].productId,
            policyList[policyId].buyerAddress,
            policyList[policyId].premium,
            policyList[policyId].payoff,
            policyList[policyId].purchaseDate,
            policyList[policyId].departureDate,
            policyList[policyId].landingDate,
            uint256(policyList[policyId].status)
        );
    }

    /**
     * @notice Get a user's policy amount
     * @param _userAddress: User's address
     * @return User's policy amount
     */
    function getUserPolicyCount(address _userAddress)
        public
        view
        returns (uint256)
    {
        return userPolicyCount[_userAddress];
    }

    /**
     * @notice Get the policy buyer by policyId
     * @param _policyId: Unique policy Id (bytes32)
     * @return The buyer of this policy
     */
    function findPolicyBuyerById(bytes32 _policyId)
        public
        view
        returns (address)
    {
        return policyList[_policyId].buyerAddress;
    }

    /// ***************************///
    ///      Helper Functions      ///
    /// ***************************///

    /**
     * @notice Change the job Id
     * @param _jobId: New job Id
     */
    function changeJobId(bytes32 _jobId) public onlyOwner {
        jobId = _jobId;
    }

    /**
     * @notice Change the oracle fee
     * @param _fee: new fee
     */
    function changeFee(uint256 _fee) public onlyOwner {
        fee = _fee;
    }

    /**
     * @notice Change the min time before departure
     * @param _newTime: New time set
     */
    function changeMinTimeBeforeDeparture(uint256 _newTime) public onlyOwner {
        MIN_TIME_BEFORE_DEPARTURE = _newTime;
    }

    /**
     * @notice Change the oracle address
     * @param _oracleAddress: New oracle address
     */
    function changeOrcaleAddress(address _oracleAddress) public onlyOwner {
        oracleAddress = _oracleAddress;
    }

    /**
     * @notice Set the new delay threshold
     * @param _threshold: New threshold
     */
    function setDelayThreshold(uint256 _threshold) public onlyOwner {
        DELAY_THRESHOLD = _threshold;
    }

    // ************************************ Main Functions ************************************ //

    /**
     * @notice start a new policy application
     * @param _userAddress: user's address (buyer)
     * @param _productId: ID of the purchased product (0: flightdelay; 1,2,3...: others) (different products)
     * @param _premium: premium of this policy (decimal 18)
     * @param _payoff: payoff of this policy (decimal 18)
     * @param _departureDate: expiry date of this policy (unix timestamp)
     */
    function newApplication(
        address _userAddress,
        uint256 _productId,
        string memory _flightNumber,
        uint256 _premium,
        uint256 _payoff,
        uint256 _departureDate,
        uint256 _landingDate,
        bytes calldata signature
    ) public returns (bytes32 _policyId) {
        require(
            _departureDate >= block.timestamp + MIN_TIME_BEFORE_DEPARTURE,
            "it's too close to the departure time, you cannot buy this policy"
        );

        bytes32 hashData = keccak256(
            abi.encode(_SUBMIT_CLAIM_TYPEHASH, _flightnNmber, msg.sender)
        );
        address signer = keccak256(hashData).toEthSignedMessageHash().recover(
            signature
        );
        require(
            _isValidSigner[signer],
            "Can only submitted by authorized signer"
        );

        // Generate the unique policyId
        bytes32 policyId = keccak256(
            abi.encodePacked(
                _userAddress,
                _productId,
                _departureDate,
                Total_Policies
            )
        );

        // Check the policy with the insurance pool status
        // May be accepted or rejected
        policyCheck(_premium, _payoff, _userAddress, policyId);

        uint256 TEMP_purchaseDate = block.timestamp;

        // Generate the policy
        policyList[policyId] = PolicyInfo(
            _productId,
            _userAddress,
            Total_Policies,
            _flightNumber,
            policyId,
            _premium,
            _payoff,
            TEMP_purchaseDate,
            _departureDate,
            _landingDate,
            PolicyStatus.INI,
            false,
            404
        );

        // Store the policy's total order with userAddress
        userPolicy[_userAddress].push(Total_Policies);
        // Update the user's policy amount
        userPolicyCount[_userAddress] += 1;
        // Update the policyOrderList
        policyOrderList[Total_Policies] = policyId;
        // Update total policies
        Total_Policies += 1;

        emit newPolicyApplication(policyId, _userAddress);

        return policyId;
    }

    /** @notice Make a claim request
     *  @param _policyOrder The total order of the policy
     *  @param _flightNumber The flight number
     *  @param _date The flight date
     *  @param _path Which data in json needs to get
     *  @param _forceUpdate Owner can force to update
     */
    function newClaimRequest(
        uint256 _policyOrder,
        string memory _flightNumber,
        string memory _date,
        string memory _path,
        bool _forceUpdate,
        bytes calldata signature
    ) public onlyOwner {
        bytes32 _policyId = policyOrderList[_policyOrder];
        require(
            block.timestamp >= policyList[_policyId].landingDate,
            "can only claim a policy after its landing"
        );
        require(
            (!policyList[_policyId].isUsed) ||
                (_forceUpdate && (msg.sender == owner)),
            "the policy status has already been settled, or you need to make a force update"
        );
        require(
            keccak256(abi.encodePacked(_flightNumber)) ==
                keccak256(abi.encodePacked(policyList[_policyId].flightNumber)),
            "wrong flight number provided"
        );
        bytes32 hashData = keccak256(
            abi.encode(_SUBMIT_CLAIM_TYPEHASH, _policyOrder, msg.sender)
        );
        address signer = keccak256(hashData).toEthSignedMessageHash().recover(
            signature
        );
        require(
            _isValidSigner[signer],
            "Can only submitted by authorized signer"
        );

        string memory _url = string(
            abi.encodePacked(
                FLIGHT_STATUS_URL,
                _flightNumber,
                "/timestamp=",
                _date
            )
        );
        bytes32 requestId = createRequestTo(
            oracleAddress,
            jobId,
            fee,
            _url,
            _path,
            1
        );
        requestList[requestId] = _policyOrder;
        policyList[_policyId].isUsed = true;
    }

    /**
     * @notice check the policy and then determine whether we can afford it
     * @param _payoff: the payoff of the policy sold
     * @param _userAddress: user's address
     * @param _policyId: the unique policy ID
     */
    function policyCheck(
        uint256 _premium,
        uint256 _payoff,
        address _userAddress,
        bytes32 _policyId
    ) internal {
        // Whether there are enough capacity in the pool
        bool _isAccepted = insurancePool.checkCapacity(_payoff);

        if (_isAccepted) {
            insurancePool.updateWhenBuy(_premium, _payoff, _userAddress);
            policyList[_policyId].status = PolicyStatus.SOLD;
            emit PolicySold(_policyId, _userAddress);

            policyToken.mintPolicyToken(_userAddress);
        } else {
            policyList[_policyId].status = PolicyStatus.DECLINED;
            emit PolicyDeclined(_policyId, _userAddress);
            revert("not sufficient capacity in the insurance pool");
        }
    }

    /**
     * @notice Creates a request to the specified Oracle contract address
     * @dev This function ignores the stored Oracle contract address and
     * will instead send the request to the address specified
     * @param _oracle The Oracle contract address to send the request to
     * @param _jobId The bytes32 JobID to be executed
     * @param _url The URL to fetch data from
     * @param _path The dot-delimited path to parse of the response
     * @param _times The number to multiply the result by
     */
    function createRequestTo(
        address _oracle,
        bytes32 _jobId,
        uint256 _payment,
        string memory _url,
        string memory _path,
        int256 _times
    ) private returns (bytes32) {
        Chainlink.Request memory req = buildChainlinkRequest(
            _jobId,
            address(this),
            this.fulfill.selector
        );
        req.add("url", _url);
        req.add("path", _path);
        req.addInt("times", _times);
        return sendChainlinkRequestTo(_oracle, req, _payment);
    }

    /**
     * @notice The fulfill method from requests created by this contract
     * @dev The recordChainlinkFulfillment protects this function from being called
     * by anyone other than the oracle address that the request was sent to
     * @param _requestId The ID that was generated for the request
     * @param _data The answer provided by the oracle
     */
    function fulfill(bytes32 _requestId, uint256 _data)
        public
        recordChainlinkFulfillment(_requestId)
    {
        oracleResponse = _data;

        uint256 order = requestList[_requestId];
        bytes32 policyId = policyOrderList[order];
        policyList[policyId].delayResult = _data;

        if (_data == 0) {
            // 0: on time
            policyExpired(
                policyList[policyId].premium,
                policyList[policyId].payoff,
                policyList[policyId].buyerAddress,
                policyId
            );
        } else if (_data <= DELAY_THRESHOLD) {
            uint256 payoff = calcPayoff(_data);
            if (payoff < policyList[policyId].payoff) {
                policyClaimed(
                    policyList[policyId].premium,
                    payoff,
                    policyList[policyId].buyerAddress,
                    policyId
                );
            } else {
                policyClaimed(
                    policyList[policyId].premium,
                    policyList[policyId].payoff,
                    policyList[policyId].buyerAddress,
                    policyId
                );
            }
        } else if (_data == 400) {
            // 400: cancelled
            policyClaimed(
                policyList[policyId].premium,
                policyList[policyId].payoff,
                policyList[policyId].buyerAddress,
                policyId
            );
        } else {
            policyExpired(
                policyList[policyId].premium,
                policyList[policyId].payoff,
                policyList[policyId].buyerAddress,
                policyId
            );
        }

        emit FulfilledOracleRequest(policyId, _requestId);
    }

    /**
     * @notice update the policy when it is expired
     * @param _premium: the premium of the policy sold
     * @param _payoff: the payoff of the policy sold
     * @param _userAddress: user's address
     * @param _policyId: the unique policy ID
     */
    function policyExpired(
        uint256 _premium,
        uint256 _payoff,
        address _userAddress,
        bytes32 _policyId
    ) internal {
        insurancePool.updateWhenExpire(_premium, _payoff, _userAddress);
        policyList[_policyId].status = PolicyStatus.EXPIRED;
        emit PolicyExpired(_policyId, _userAddress);
    }

    /**
     * @notice update the policy when it is claimed
     * @param _premium: the premium of the policy sold
     * @param _payoff: the payoff of the policy sold
     * @param _userAddress: user's address
     * @param _policyId: the unique policy ID
     */
    function policyClaimed(
        uint256 _premium,
        uint256 _payoff,
        address _userAddress,
        bytes32 _policyId
    ) internal {
        insurancePool.payClaim(_premium, _payoff, _userAddress);
        policyList[_policyId].status = PolicyStatus.CLAIMED;
        emit PolicyClaimed(_policyId, _userAddress);
    }

    /**
     * @notice The payoff formula
     * @param _delay Delay in minutes
     * @return the final payoff volume
     */
    function calcPayoff(uint256 _delay) internal pure returns (uint256) {
        uint256 payoff = 0;

        // payoff model 1 - linear
        if (_delay <= 60) {
            payoff = _delay;
        } else if (_delay > 60 && _delay <= 120) {
            payoff = 60 + (_delay - 60) * 2;
        } else if (_delay > 120 && _delay <= 240) {
            payoff = 180 + (_delay - 120) * 3;
        }

        payoff = payoff * 1e18;
        return payoff;
    }

    /**
     * @notice Update information when a policy token's ownership has been transferred
     * @param _tokenId: Token Id of the policy token
     * @param _oldOwner: The initial owner
     * @param _newOwner: The new owner
     */
    function policyOwnerTransfer(
        uint256 _tokenId,
        address _oldOwner,
        address _newOwner
    ) external {
        require(
            msg.sender == address(policyToken),
            "only called from the policy token contract"
        );

        bytes32 policyId = policyOrderList[_tokenId];
        require(
            _oldOwner == policyList[policyId].buyerAddress,
            "the previous owner is wrong"
        );

        policyList[policyId].buyerAddress = _newOwner;
        emit PolicyOwnerTransfer(_tokenId, _newOwner);
    }

    function encodePack1(
        uint256 _order,
        string memory _flightNumber,
        bytes32 _policyId,
        uint256 _productId,
        address _userAddress
    ) internal pure returns (string memory _result1) {
        _result1 = string(
            abi.encodePacked(
                "\nPolicy",
                _order.toString(),
                ": \n{FlightNumber: ",
                _flightNumber,
                ": \nPolicyId: ",
                bytes32ToString(_policyId),
                ", \nProductId: ",
                _productId.toString(),
                ", \nBuyerAddress: ",
                addressToString(_userAddress)
            )
        );
    }

    function encodePack2(
        uint256 _premium,
        uint256 _payoff,
        uint256 _purchaseDate,
        uint256 _departureDate,
        uint256 _landingDate,
        uint256 _status,
        string memory _isUsed,
        uint256 _delayResult
    ) internal pure returns (string memory _result2) {
        _result2 = string(
            abi.encodePacked(
                ", \nPremium: ",
                (_premium / 10**18).toString(),
                ", \nPayoff: ",
                (_payoff / 10**18).toString(),
                ", \nPurchaseDate: ",
                (_purchaseDate).toString(),
                ", \nDepartureDate: ",
                (_departureDate).toString(),
                ", \nLandingDate: ",
                (_landingDate).toString(),
                ", \nStatus: ",
                uint256(_status).toString(),
                ", \nIsUsed: ",
                _isUsed,
                ", \nDelay Results: ",
                _delayResult.toString(),
                "}"
            )
        );
    }
}
