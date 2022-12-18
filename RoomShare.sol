// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

contract RoomShare {
  uint public roomId = 0;
  struct Room{
    uint id;
    string name;
    string location;
    bool isActive;
    uint price;
    address owner;
    bool[] isRented;
  }

  uint public rentId = 0;
  struct Rent{
      uint id;
      uint rId;
      uint yearOfRent;  
      uint checkInDate;
      uint checkOutDate;
      address renter;
  }

  event NewRoom (
      uint256 indexed roomId
  );

  event NewRent (
      uint indexed roomId,
      uint256 indexed rentId
  );

  event Transfer(
    address sender, 
    address recipient, 
    uint amount
  );

  // will be updated by share
  mapping(uint => Room) public roomId2room;
  // will be updated by rent
  mapping(address => Rent[]) public renter2rent;
  mapping(uint => Rent[]) public roomId2rent;

  function getMyRents() external view returns(Rent[] memory) {
    /* 함수를 호출한 유저의 대여 목록을 가져온다. */
      address user = msg.sender; //
      return renter2rent[user];
  }

  function getRoomRentHistory(uint _roomId) external view returns(Rent[] memory) {
    /* 특정 방의 대여 히스토리를 보여준다. */
    return roomId2rent[_roomId];
  }

  function getAllRooms() external view returns(Room[] memory) {

    Room[] memory rooms;
    for (uint256 i = 0; i < roomId; i++) {
      rooms[i] = roomId2room[i];
    }

    return rooms;
  }

  function checkRented(uint rid, uint checkInDate, uint checkOutDate) external view returns (uint) {

    uint idx = checkInDate;
    Room memory room = roomId2room[rid];
    bool found = false;

    while (idx < checkOutDate) {
      if (room.isRented[idx] == true) {
        found = true;
        break;
      }
      idx += 1;
    }

    if (found == true)
      return 1;
    else
      return 0;
  }

  function shareRoom( string calldata name, 
                      string calldata location, 
                      uint price ) external {
    /**
     * 1. isActive 초기값은 true로 활성화, 함수를 호출한 유저가 방의 소유자이며, 365 크기의 boolean 배열을 생성하여 방 객체를 만든다.
     * 2. 방의 id와 방 객체를 매핑한다.
     */
    Room memory room = Room(roomId, name, location, true, price, msg.sender, new bool[](365));
    roomId2room[roomId] = room;
    emit NewRoom(roomId++);
  }

  function rentRoom(uint _roomId, uint year, uint checkInDate, uint checkOutDate) payable external {
    /**
     * 1. roomId에 해당하는 방을 조회하여 아래와 같은 조건을 만족하는지 체크한다.
     *    a. 현재 활성화(isActive) 되어 있는지
     *    b. 체크인날짜와 체크아웃날짜 사이에 예약된 날이 있는지 
     *    c. 함수를 호출한 유저가 보낸 이더리움 값이 대여한 날에 맞게 지불되었는지(단위는 1 Finney, 10^15 Wei) 
     * 2. 방의 소유자에게 값을 지불하고 (msg.value 사용) createRent를 호출한다.
     * *** 체크아웃 날짜에는 퇴실하여야하며, 해당일까지 숙박을 이용하려면 체크아웃날짜는 그 다음날로 변경하여야한다. ***
     */

    Room storage room = roomId2room[_roomId];
    require(room.isActive == true, "shoule be active"); // a

    uint from = checkInDate;
    uint to = checkOutDate;
    uint duration = 0;
    while (from < to) { // b
      bool rented = room.isRented[from];
      require(rented == false,"already rented");
      from += 1;
    }

    // duration = checkOutDate - checkInDate + 1;
    duration = checkOutDate - checkInDate; // does not checkout 
    require(msg.value == (duration * room.price * 10 ** 15), "invalid price"); // c

    _createRent(_roomId, year, checkInDate, checkOutDate);
    _sendFunds(room.owner, msg.value);
  }

  function _createRent(uint256 _roomId, uint year, uint256 checkInDate, uint256 checkoutDate) internal {
    /**
     * 1. 함수를 호출한 사용자 계정으로 대여 객체를 만들고, 변수 저장 공간에 유의하며 체크인날짜부터 체크아웃날짜에 해당하는 배열 인덱스를 체크한다(초기값은 false이다.).
     * 2. 계정과 대여 객체들을 매핑한다. (대여 목록)
     * 3. 방 id와 대여 객체들을 매핑한다. (대여 히스토리)
     */
    
    Rent memory rent = Rent(rentId, _roomId, year, checkInDate+1, checkoutDate+1, msg.sender);
    Room storage room = roomId2room[_roomId];

    // do not include checkout date
    uint from = checkInDate;
    uint to = checkoutDate;
    while (from < to) {
      room.isRented[from] = true;
      from += 1;
    } 

    renter2rent[msg.sender].push(rent);
    roomId2rent[_roomId].push(rent);

    emit NewRent(_roomId, rentId++);
  }

  function _sendFunds (address owner, uint256 value) internal {
      payable(owner).transfer(value);
  }

  function recommendDate(uint _roomId, uint checkInDate, uint checkOutDate) external view returns(uint[2] memory) {
    /**
     * 대여가 이미 진행되어 해당 날짜에 대여가 불가능 할 경우, 
     * 기존에 예약된 날짜가 언제부터 언제까지인지 반환한다.
     * checkInDate(체크인하려는 날짜) <= 대여된 체크인 날짜 , 대여된 체크아웃 날짜 < checkOutDate(체크아웃하려는 날짜)
     */
    Room storage room = roomId2room[_roomId];
    uint[2] memory date;
    uint idx = checkInDate;
    bool found = false;

    while (idx <= checkOutDate) {
      if (room.isRented[idx] == true && found == false) {
        date[0] = idx+1;
        found = true;
      }

      if (room.isRented[idx] == false && found == true) {
        date[1] = idx+1;
        break;
      }

      idx += 1;
    }

    return date;
  }

  function changeRoomState(uint roomid, bool state) public  {
    Room storage room = roomId2room[roomid];
    room.isActive = state;
  }

  function initializeRoom(uint roomid) public {
    Room storage room = roomId2room[roomid];

    for (uint i = 0; i < 365; i++) {
      room.isRented[i] = false;
    }

    Rent[] storage rents = roomId2rent[roomid];
    address[] memory renters;
    for (uint i = 0; i < rents.length; i++) {
      renters[i] = rents[i].renter;
      // renters.push(rents[i].renter);
    }

    delete roomId2rent[roomid];

    for (uint i = 0; i < renters.length; i++) {
      address renter = renters[i];
      for (uint j = 0; j < renter2rent[renter].length; j++) {
        if (renter2rent[renter][j].rId == roomid) {
          delete renter2rent[renter][j];
        }
      }
    }

  }
}
