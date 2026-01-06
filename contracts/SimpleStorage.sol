// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract SimpleStorage {
    // boolean, uint, int, address, bytes
    // bool hasFavoriteNumber = true;
    uint256 public favoriteNumber;

    // uint256 public favoriteNumber = 123; // uint256 is the same as uint
    // string public favoriteNumberInText = "One hundred twenty three";
    // bool public hasFavoriteNumber = true;
    // address public favoriteAddress = 0x0000000000000000000000000000000000000000;
    // bytes32 favoriteBytes = "cat";
    People public person = People({favoriteNumber: 2, name: "WINSTON"});

    function store(uint256 _favoriteNumber) public {
        favoriteNumber = _favoriteNumber;
        // uint256 testVar = 5;

    }

    // function retrieve() public view returns(uint256) {
    //     return favoriteNumber;
    // }

    // function add() public pure returns (uint256) {
    //     return(1+1);
    // }

    struct People {
        uint256 favoriteNumber;
        string name;
    }

    uint256[] public favoriteNumberList;
    People[] public peopleList; // array of structs
    // mapping(string => uint256) public nameToFavoriteNumber;

    function addPerson(string memory _name, uint256 _favoriteNumber) public {
        peopleList.push(People(_favoriteNumber, _name));
        // People memory newPerson = People({favoriteNumber:_favoriteNumber,name: _name});
        // peopleList.push(newPerson);
        // nameToFavoriteNumber[_name] = _favoriteNumber;
        // favoriteNumberList.push(_favoriteNumber);
    }






}
