// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;
import "./IPolicyTypes.sol";

/**
 * @title  IPolicyFlow
 * @notice This is the interface of PolicyFlow contract.
 *         Contains some type definations, event list and function declarations.
 */
interface IPolicyFlow is IPolicyTypes {
    /// @notice Event list
    event newPolicyApplication(uint256 _policyID, address indexed _userAddress);
    event PolicySold(uint256 _policyID, address indexed _userAddress);
    event PolicyDeclined(uint256 _policyID, address indexed _userAddress);
    event PolicyClaimed(uint256 _policyID, address indexed _userAddress);
    event PolicyExpired(uint256 _policyID, address indexed _userAddress);
    event FulfilledOracleRequest(uint256 _policyId, bytes32 _requestId);
    event PolicyOwnerTransfer(uint256 indexed _tokenId, address _newOwner);
    event DelayThresholdSet(uint256 _thresholdMin, uint256 _thresholdMax);

    /// @notice Function declarations

    /// @notice Apply for a new policy
    function newApplication(
        uint256 _productId,
        string memory _flightNumber,
        uint256 _premium,
        uint256 _departureDate,
        uint256 _landingDate,
        uint256 _deadline,
        bytes calldata signature
    ) external returns (uint256 policyId);

    /// @notice Start a new claim request
    function newClaimRequest(
        uint256 _policyId,
        string memory _flightNumber,
        string memory _date,
        string memory _path,
        bool _forceUpdate
    ) external;

    /// @notice View a user's policy info
    function viewUserPolicy(address)
        external
        view
        returns (PolicyInfo[] memory);

    /// @notice Get the policy info by its policyId
    function getPolicyInfoById(uint256)
        external
        view
        returns (PolicyInfo memory);

    /// @notice Update when the policy token is transferred to another owner
    function policyOwnerTransfer(
        uint256,
        address,
        address
    ) external;

    /// @notice Do the final settlement when receiving the oracle result
    function finalSettlement(bytes32 _requestId, uint256 _result) external;

    function getChainlinkToken() external view returns (address);

    function getUserPolicyCount(address) external view returns (uint256);
}
