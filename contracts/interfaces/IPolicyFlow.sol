// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPolicyFlow {
    struct policyInfo {
        uint256 productId;
        address buyerAddress;
        bytes32 policyId;
        uint256 premium;
        uint256 payoff;
        uint256 expiryDate;
        bool isClaimed;
    }

    event newPolicyApplication(bytes32 _policyID, address);
    event PolicySold(bytes32 _policyID, address);
    event PolicyDeclined(bytes32 _policyID, address);
    event PolicyClaimed(bytes32 _policyID, address);
    event PolicyExpired(bytes32 _policyID, address);
    event FulfilledOracleRequest(bytes32 _policyId, bytes32 _requestId);

    function newApplication(
        address _userAddress,
        uint256 _productId,
        uint256 _premium,
        uint256 _payoff,
        uint256 _expiryDate
    ) external returns (string memory);

    function policyCheck(
        uint256,
        uint256,
        address,
        bytes32
    ) external;

    function policyExpired(
        uint256,
        uint256,
        address,
        bytes32
    ) external;

    function policyClaimed(
        uint256,
        uint256,
        address,
        bytes32
    ) external;

    function viewPolicy(address) external view returns (string memory);

    function getPolicyInfoByCount(uint256)
        external
        view
        returns (
            bytes32,
            uint256,
            address,
            uint256,
            uint256,
            uint256
        );
}
