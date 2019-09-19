/**
 * Copyright (c) 2018 Centroida.AI All rights reserved.
 */

package main

import (
	"github.com/hyperledger/fabric/core/chaincode/shim"
	"github.com/hyperledger/fabric/protos/peer"
)

func (ac *ChaincodeStruct) storeRestorationCode(stub shim.ChaincodeStubInterface, args []string) peer.Response {

	logger := shim.NewLogger("storeRestorationCodeLogger")

	if len(args) != 2 {
		logger.Error("Two arguments expected")
		return shim.Error("Two arguments expected")
	}

	id := args[0]
	code := args[1]

	logger.Info("Hashing the passed restoration code.")
	hashedCode := ac.utils.stringToSHA256HexString(code)

	logger.Info("Hashing the UUID.")
	hashedID := ac.utils.stringToSHA256HexString(id)
	key := ac.utils.getKey(RestorationCodeChaincode, hashedID)

	logger.Info("Check if the identity is associated with a restoration code.")
	hasRestorationCode, err := ac.utils.hasValue(stub, key)

	if err != nil {
		logger.Errorf("Error checking if the user is already associated to a restoration code %v", err)
		return shim.Error("Error checking if the user is already associated to a restoration code")
	}

	if hasRestorationCode {
		logger.Error("The user is already associated to a restoration code.")
		return shim.Error("The user is already associated to a restoration code.")
	}

	logger.Info("Updating the state of the ledger")
	err = ac.utils.setStringValue(stub, key, hashedCode)

	if err != nil {
		logger.Errorf("Error saving restoration code hash %v", err)
		return shim.Error("Error saving restoration code hash")
	}

	logger.Info("Successfully stored the restoration code of the user")
	return shim.Success(nil)
}