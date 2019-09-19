/**
 * Copyright (c) 2018 Centroida.AI All rights reserved.
 */

package main

import (
	"github.com/hyperledger/fabric/core/chaincode/shim"
	"github.com/hyperledger/fabric/protos/peer"
)

func (ac *ChaincodeStruct) storeSecurityCode(stub shim.ChaincodeStubInterface, args []string) peer.Response {

	logger := shim.NewLogger("registerLogger")

	if len(args) != 2 {
		logger.Error("Two arguments expected")
		return shim.Error("Two arguments expected")
	}

	id := args[0]
	code := args[1]

	logger.Debug("UUID: %s", id)

	logger.Info("Hashing the passed code.")
	hashedCode := ac.utils.stringToSHA256HexString(code)

	logger.Info("Hashing the UUID.")
	hashedID := ac.utils.stringToSHA256HexString(id)
	key := ac.utils.getKey(SecurityCodeChaincode, hashedID)

	logger.Info("Check if the identity is already registered")
	hasSecurityCode, err := ac.utils.hasValue(stub, key)

	if err != nil {
		logger.Error("Error checking if the user is already related to a code", err)
		return shim.Error("Error checking if the user is already related to a code")
	}

	if hasSecurityCode {
		logger.Error("The user is already related to a code.")
		return shim.Error("The user is already related to a code.")
	}

	logger.Info("Updating the state of the ledger")
	err = ac.utils.setStringValue(stub, key, hashedCode)

	if err != nil {
		logger.Errorf("Error saving authentication hash %v", err)
		return shim.Error("Error saving authentication hash")
	}

	logger.Info("Successfully stored the code of the user")
	return shim.Success(nil)
}

func (ac *ChaincodeStruct) validateSecurityCode(stub shim.ChaincodeStubInterface, args []string) peer.Response {

	logger := shim.NewLogger("registerLogger")

	if len(args) != 2 {
		logger.Error("Two arguments expected")
		return shim.Error("Two arguments expected")
	}
	id := args[0]
	code := args[1]

	logger.Debug("UUID: %s", id)

	err := ac.tokenHelper.validateSecurityCode(stub, id, code)

	if err != nil {
		logger.Errorf("Error validating security code %v", err)
		return shim.Error(err.Error())
	}

	return shim.Success(nil)
}

func (ac *ChaincodeStruct) hasSecurityCode(stub shim.ChaincodeStubInterface, args []string) peer.Response {

	logger := shim.NewLogger("registerLogger")

	if len(args) != 1 {
		logger.Error("One argument expected")
		return shim.Error("One argument expected")
	}
	id := args[0]

	logger.Info("Hashing the UUID.")
	hashedID := ac.utils.stringToSHA256HexString(id)
	key := ac.utils.getKey(SecurityCodeChaincode, hashedID)

	logger.Debug("UUID: %s", id)
	logger.Info("Check if the identity is already registered")

	hasSecurityCode, err := ac.utils.hasValue(stub, key)

	if err != nil {
		logger.Error("Error checking if the user is already related to a code", err)
		return shim.Error("Error checking if the user is already related to a code")
	}

	if hasSecurityCode {
		return shim.Success(nil)
	}

	logger.Error("The user hasn't registered security code.")
	return shim.Error("The user hasn't registered security code.")
}
