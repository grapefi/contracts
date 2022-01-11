// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/math/Math.sol";

import "./lib/SafeMath8.sol";
import "./owner/Operator.sol";
import "./interfaces/IOracle.sol";

/*

 ██████╗ ██████╗  █████╗ ██████╗ ███████╗    ███████╗██╗███╗   ██╗ █████╗ ███╗   ██╗ ██████╗███████╗
██╔════╝ ██╔══██╗██╔══██╗██╔══██╗██╔════╝    ██╔════╝██║████╗  ██║██╔══██╗████╗  ██║██╔════╝██╔════╝
██║  ███╗██████╔╝███████║██████╔╝█████╗      █████╗  ██║██╔██╗ ██║███████║██╔██╗ ██║██║     █████╗  
██║   ██║██╔══██╗██╔══██║██╔═══╝ ██╔══╝      ██╔══╝  ██║██║╚██╗██║██╔══██║██║╚██╗██║██║     ██╔══╝  
╚██████╔╝██║  ██║██║  ██║██║     ███████╗    ██║     ██║██║ ╚████║██║  ██║██║ ╚████║╚██████╗███████╗
 ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚══════╝    ╚═╝     ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝╚══════╝
                                                                                                    
*/

contract Grape is ERC20Burnable, Operator {
    using SafeMath8 for uint8;
    using SafeMath for uint256;

    // Initial distribution for the first 24h genesis pools
    uint256 public constant INITIAL_GENESIS_POOL_DISTRIBUTION = 2400 ether;
    // Initial distribution for the day 2-5 GRAPE-WETH LP -> GRAPE pool
    uint256 public constant INITIAL_GRAPE_POOL_DISTRIBUTION = 21600 ether;
    // Distribution for airdrops wallet
    uint256 public constant INITIAL_AIRDROP_WALLET_DISTRIBUTION = 1000 ether;

    // Have the rewards been distributed to the pools
    bool public rewardPoolDistributed = false;

    address public grapeOracle;

    /**
     * @notice Constructs the GRAPE ERC-20 contract.
     */
    constructor() public ERC20("Grape Finance", "GRAPE") {
        // Mints 1 GRAPE to contract creator for initial pool setup
        _mint(msg.sender, 1 ether);   
    }

    function _getGrapePrice() internal view returns (uint256 _grapePrice) {
        try IOracle(grapeOracle).consult(address(this), 1e18) returns (uint144 _price) {
            return uint256(_price);
        } catch {
            revert("Grape: failed to fetch GRAPE price from Oracle");
        }
    }

    function setGrapeOracle(address _grapeOracle) public onlyOperator {
        require(_grapeOracle != address(0), "oracle address cannot be 0 address");
        grapeOracle = _grapeOracle;
    }

    /**
     * @notice Operator mints GRAPE to a recipient
     * @param recipient_ The address of recipient
     * @param amount_ The amount of GRAPE to mint to
     * @return whether the process has been done
     */
    function mint(address recipient_, uint256 amount_) public onlyOperator returns (bool) {
        uint256 balanceBefore = balanceOf(recipient_);
        _mint(recipient_, amount_);
        uint256 balanceAfter = balanceOf(recipient_);

        return balanceAfter > balanceBefore;
    }

    function burn(uint256 amount) public override {
        super.burn(amount);
    }

    function burnFrom(address account, uint256 amount) public override onlyOperator {
        super.burnFrom(account, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), allowance(sender, _msgSender()).sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    /**
     * @notice distribute to reward pool (only once)
     */
    function distributeReward(
        address _genesisPool,
        address _grapePool,
        address _airdropWallet
    ) external onlyOperator {
        require(!rewardPoolDistributed, "only can distribute once");
        require(_genesisPool != address(0), "!_genesisPool");
        require(_grapePool != address(0), "!_grapePool");
        require(_airdropWallet != address(0), "!_airdropWallet");
        rewardPoolDistributed = true;
        _mint(_genesisPool, INITIAL_GENESIS_POOL_DISTRIBUTION);
        _mint(_grapePool, INITIAL_GRAPE_POOL_DISTRIBUTION);
        _mint(_airdropWallet, INITIAL_AIRDROP_WALLET_DISTRIBUTION);
    }

    function governanceRecoverUnsupported(
        IERC20 _token,
        uint256 _amount,
        address _to
    ) external onlyOperator {
        _token.transfer(_to, _amount);
    }
}
