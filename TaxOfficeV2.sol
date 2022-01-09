// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "./owner/Operator.sol";
import "./interfaces/ITaxable.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IERC20.sol";

contract TaxOfficeV2 is Operator {
    using SafeMath for uint256;

    address public grape = address(0x522348779DCb2911539e76A1042aA922F9C47Ee3);
    address public weth = address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    address public uniRouter = address(0x10ED43C718714eb63d5aA57B78B54704E256024E);

    mapping(address => bool) public taxExclusionEnabled;

    function setTaxTiersTwap(uint8 _index, uint256 _value) public onlyOperator returns (bool) {
        return ITaxable(grape).setTaxTiersTwap(_index, _value);
    }

    function setTaxTiersRate(uint8 _index, uint256 _value) public onlyOperator returns (bool) {
        return ITaxable(grape).setTaxTiersRate(_index, _value);
    }

    function enableAutoCalculateTax() public onlyOperator {
        ITaxable(grape).enableAutoCalculateTax();
    }

    function disableAutoCalculateTax() public onlyOperator {
        ITaxable(grape).disableAutoCalculateTax();
    }

    function setTaxRate(uint256 _taxRate) public onlyOperator {
        ITaxable(grape).setTaxRate(_taxRate);
    }

    function setBurnThreshold(uint256 _burnThreshold) public onlyOperator {
        ITaxable(grape).setBurnThreshold(_burnThreshold);
    }

    function setTaxCollectorAddress(address _taxCollectorAddress) public onlyOperator {
        ITaxable(grape).setTaxCollectorAddress(_taxCollectorAddress);
    }

    function excludeAddressFromTax(address _address) external onlyOperator returns (bool) {
        return _excludeAddressFromTax(_address);
    }

    function _excludeAddressFromTax(address _address) private returns (bool) {
        if (!ITaxable(grape).isAddressExcluded(_address)) {
            return ITaxable(grape).excludeAddress(_address);
        }
    }

    function includeAddressInTax(address _address) external onlyOperator returns (bool) {
        return _includeAddressInTax(_address);
    }

    function _includeAddressInTax(address _address) private returns (bool) {
        if (ITaxable(grape).isAddressExcluded(_address)) {
            return ITaxable(grape).includeAddress(_address);
        }
    }

    function taxRate() external returns (uint256) {
        return ITaxable(grape).taxRate();
    }

    function addLiquidityTaxFree(
        address token,
        uint256 amtGrape,
        uint256 amtToken,
        uint256 amtGrapeMin,
        uint256 amtTokenMin
    )
        external
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        require(amtGrape != 0 && amtToken != 0, "amounts can't be 0");
        _excludeAddressFromTax(msg.sender);

        IERC20(grape).transferFrom(msg.sender, address(this), amtGrape);
        IERC20(token).transferFrom(msg.sender, address(this), amtToken);
        _approveTokenIfNeeded(grape, uniRouter);
        _approveTokenIfNeeded(token, uniRouter);

        _includeAddressInTax(msg.sender);

        uint256 resultAmtGrape;
        uint256 resultAmtToken;
        uint256 liquidity;
        (resultAmtGrape, resultAmtToken, liquidity) = IUniswapV2Router(uniRouter).addLiquidity(
            grape,
            token,
            amtGrape,
            amtToken,
            amtGrapeMin,
            amtTokenMin,
            msg.sender,
            block.timestamp
        );

        if (amtGrape.sub(resultAmtGrape) > 0) {
            IERC20(grape).transfer(msg.sender, amtGrape.sub(resultAmtGrape));
        }
        if (amtToken.sub(resultAmtToken) > 0) {
            IERC20(token).transfer(msg.sender, amtToken.sub(resultAmtToken));
        }
        return (resultAmtGrape, resultAmtToken, liquidity);
    }

    function addLiquidityETHTaxFree(
        uint256 amtGrape,
        uint256 amtGrapeMin,
        uint256 amtEthMin
    )
        external
        payable
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        require(amtGrape != 0 && msg.value != 0, "amounts can't be 0");
        _excludeAddressFromTax(msg.sender);

        IERC20(grape).transferFrom(msg.sender, address(this), amtGrape);
        _approveTokenIfNeeded(grape, uniRouter);

        _includeAddressInTax(msg.sender);

        uint256 resultAmtGrape;
        uint256 resultAmtEth;
        uint256 liquidity;
        (resultAmtGrape, resultAmtEth, liquidity) = IUniswapV2Router(uniRouter).addLiquidityETH{value: msg.value}(
            grape,
            amtGrape,
            amtGrapeMin,
            amtEthMin,
            msg.sender,
            block.timestamp
        );

        if (amtGrape.sub(resultAmtGrape) > 0) {
            IERC20(grape).transfer(msg.sender, amtGrape.sub(resultAmtGrape));
        }
        return (resultAmtGrape, resultAmtEth, liquidity);
    }

    function setTaxableGrapeOracle(address _grapeOracle) external onlyOperator {
        ITaxable(grape).setGrapeOracle(_grapeOracle);
    }

    function transferTaxOffice(address _newTaxOffice) external onlyOperator {
        ITaxable(grape).setTaxOffice(_newTaxOffice);
    }

    function taxFreeTransferFrom(
        address _sender,
        address _recipient,
        uint256 _amt
    ) external {
        require(taxExclusionEnabled[msg.sender], "Address not approved for tax free transfers");
        _excludeAddressFromTax(_sender);
        IERC20(grape).transferFrom(_sender, _recipient, _amt);
        _includeAddressInTax(_sender);
    }

    function setTaxExclusionForAddress(address _address, bool _excluded) external onlyOperator {
        taxExclusionEnabled[_address] = _excluded;
    }

    function _approveTokenIfNeeded(address _token, address _router) private {
        if (IERC20(_token).allowance(address(this), _router) == 0) {
            IERC20(_token).approve(_router, type(uint256).max);
        }
    }
}