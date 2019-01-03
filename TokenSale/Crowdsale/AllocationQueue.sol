pragma solidity ^0.4.21;

import '../Ownable.sol';
import '../SafeMath.sol';
import '../Token/ERC20Basic.sol';

contract AllocationQueue is Ownable {
    using SafeMath for uint256;

    // address => date => tokens
    mapping(address => mapping(uint256 => uint256)) public queue;
    uint256 public totalShare;

    ERC20Basic public token;

    uint constant DAY_IN_SECONDS = 86400;
    uint constant YEAR_IN_SECONDS = 31536000;
    uint constant LEAP_YEAR_IN_SECONDS = 31622400;

    uint16 constant ORIGIN_YEAR = 1970;
    uint constant LEAP_YEARS_BEFORE_ORIGIN_YEAR = 477;

    function AllocationQueue(ERC20Basic _token) public {
        token = _token;
    }

    function isLeapYear(uint16 year) internal pure returns (bool) {
        if (year % 4 != 0) {
            return false;
        }
        if (year % 100 != 0) {
            return true;
        }
        if (year % 400 != 0) {
            return false;
        }
        return true;
    }

    function groupDates(uint256 _date) internal view returns (uint256) {
        uint secondsAccountedFor = 0;

        // Year
        uint year = ORIGIN_YEAR + _date / YEAR_IN_SECONDS;
        uint numLeapYears = ((year - 1) / 4 - (year - 1) / 100 + (year - 1) / 400) - LEAP_YEARS_BEFORE_ORIGIN_YEAR; // leapYearsBefore(year) - LEAP_YEARS_BEFORE_ORIGIN_YEAR

        secondsAccountedFor += LEAP_YEAR_IN_SECONDS * numLeapYears;
        secondsAccountedFor += YEAR_IN_SECONDS * (year - ORIGIN_YEAR - numLeapYears);

        while (secondsAccountedFor > _date) {
            if (isLeapYear(uint16(year - 1))) {
                secondsAccountedFor -= LEAP_YEAR_IN_SECONDS;
            }
            else {
                secondsAccountedFor -= YEAR_IN_SECONDS;
            }
            year -= 1;
        }

        // Month
        uint8 month;

        uint seconds31 = 31 * DAY_IN_SECONDS;
        uint seconds30 = 30 * DAY_IN_SECONDS;
        uint secondsFeb = (isLeapYear(uint16(year)) ? 29 : 28) * DAY_IN_SECONDS;

        if (secondsAccountedFor + seconds31 > _date) {
            month = 1;
        } else if (secondsAccountedFor + seconds31 + secondsFeb > _date) {
            month = 2;
        } else if (secondsAccountedFor + 2 * seconds31 + secondsFeb > _date) {
            month = 3;
        } else if (secondsAccountedFor + 2 * seconds31 + seconds30 + secondsFeb > _date) {
            month = 4;
        } else if (secondsAccountedFor + 3 * seconds31 + seconds30 + secondsFeb > _date) {
            month = 5;
        } else if (secondsAccountedFor + 3 * seconds31 + 2 * seconds30 + secondsFeb > _date) {
            month = 6;
        } else if (secondsAccountedFor + 4 * seconds31 + 2 * seconds30 + secondsFeb > _date) {
            month = 7;
        } else if (secondsAccountedFor + 5 * seconds31 + 2 * seconds30 + secondsFeb > _date) {
            month = 8;
        } else if (secondsAccountedFor + 5 * seconds31 + 3 * seconds30 + secondsFeb > _date) {
            month = 9;
        } else if (secondsAccountedFor + 6 * seconds31 + 3 * seconds30 + secondsFeb > _date) {
            month = 10;
        } else if (secondsAccountedFor + 6 * seconds31 + 4 * seconds30 + secondsFeb > _date) {
            month = 11;
        } else {
            month = 12;
        }

        return uint256(year) * 100 + uint256(month);
    }

    function addShare(address _beneficiary, uint256 _tokens, uint256 _freezeTime) onlyOwner external {
        require(_beneficiary != 0x0);
        require(token.balanceOf(this) == totalShare.add(_tokens));

        uint256 currentDate = groupDates(now);
        uint256 unfreezeDate = groupDates(now.add(_freezeTime));

        require(unfreezeDate > currentDate);

        queue[_beneficiary][unfreezeDate] = queue[_beneficiary][unfreezeDate].add(_tokens);
        totalShare = totalShare.add(_tokens);
    }

    function unlockFor(address _owner, uint256 _date) public {
        uint256 date = groupDates(_date);

        require(date <= groupDates(now));

        uint256 share = queue[_owner][date];

        queue[_owner][date] = 0;

        if (share > 0) {
            token.transfer(_owner,share);
            totalShare = totalShare.sub(share);
        }
    }

    // Available to unlock funds for the date. Constant.
    function getShare(address _owner, uint256 _date) public view returns(uint256){
        uint256 date = groupDates(_date);

        return queue[_owner][date];
    }
}
