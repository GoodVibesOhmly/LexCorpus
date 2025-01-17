// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.0;

import "../interfaces/IERC20.sol";

/// @notice Simple bilateral escrow for ETH and ERC-20/721 tokens.
contract LexEscrowSimple {
    uint256 public escrowCount;
    
    mapping(uint256 => Escrow) public escrows;
    
    event Deposit(
        bool nft,
        address indexed depositor, 
        address indexed receiver, 
        IERC20 token, 
        uint256 amount, 
        uint256 indexed registration,
        string details);
    event Release(uint256 indexed registration);
    
    struct Escrow {  
        bool nft;
        address depositor;
        address receiver;
        IERC20 token;
        uint256 value;
    }
    
    /// @notice Deposits ETH/ERC-20 into escrow.
    /// @param receiver The account that receives funds.
    /// @param token The asset used for funds.
    /// @param value The amount of funds.
    /// @param details Describes context of escrow - stamped into event.
    function deposit(address receiver, IERC20 token, uint256 value, string memory details) payable public virtual {
        if (address(token) == address(0)) {
            require(msg.value == value, "WRONG_MSG_VALUE");
        } else {
            token.transferFrom(msg.sender, address(this), value);
        }
        
        /// @dev Increment registered escrows and assign # to escrow deposit.
        unchecked {
            escrowCount++;
        }
        uint256 registration = escrowCount;
        escrows[registration] = Escrow(false, msg.sender, receiver, token, value);
        
        emit Deposit(false, msg.sender, receiver, token, value, registration, details);
    }
    
    /// @notice Deposits ERC-721 into escrow.
    /// @param receiver The account that receives `tokenId`.
    /// @param token The NFT asset.
    /// @param tokenId The NFT `tokenId`.
    /// @param details Describes context of escrow - stamped into event.
    function depositNFT(address receiver, IERC20 token, uint256 tokenId, string memory details) public virtual {
        token.transferFrom(msg.sender, address(this), tokenId);
        
        /// @dev Increment registered escrows and assign # to escrow deposit.
        unchecked {
            escrowCount++;
        }
        uint256 registration = escrowCount;
        escrows[registration] = Escrow(true, msg.sender, receiver, token, tokenId);
        
        emit Deposit(true, msg.sender, receiver, token, tokenId, registration, details);
    }
    
    /// @notice Releases escrowed assets to designated `receiver`. 
    /// @param registration The index of escrow deposit.
    function release(uint256 registration) public virtual {
        Escrow storage escrow = escrows[registration];
        
        require(msg.sender == escrow.depositor, "NOT_DEPOSITOR");
        require(!escrow.nft, "NFT");
        
        if (address(escrow.token) == address(0)) {
            (bool success, ) = escrow.receiver.call{value: escrow.value}("");
            require(success, "ETH_TRANSFER_FAILED");
        } else {
            escrow.token.transfer(escrow.receiver, escrow.value);
        }
        
        emit Release(registration);
    }
    
    /// @notice Releases escrowed NFT `tokenId` to designated `receiver`. 
    /// @param registration The index of escrow deposit.
    function releaseNFT(uint256 registration) public virtual {
        Escrow storage escrow = escrows[registration];
        
        require(msg.sender == escrow.depositor, "NOT_DEPOSITOR");
        require(escrow.nft, "NOT_NFT");
        
        escrow.token.transferFrom(address(this), escrow.receiver, escrow.value);
        
        emit Release(registration);
    }
}
