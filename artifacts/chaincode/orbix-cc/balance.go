package main

import (
	"strconv"

	"github.com/hyperledger/fabric/core/chaincode/shim"
	"github.com/hyperledger/fabric/protos/peer"
	"github.com/pkg/errors"
)

func (t *ChaincodeStruct) getBalance(stub shim.ChaincodeStubInterface, args []string) peer.Response {
	logger := shim.NewLogger("getBalanceLogger")
	if len(args) != 1 {
		logger.Error("[getBalance]: Only one argument expected")
		return shim.Error("[getBalance]: Only one argument expected")
	}

	userID := args[0]
	logger.Info("UserID: ", userID)

	balance, err := t.tokenHelper.retrieveBalance(stub, userID)
	if err != nil {
		err = errors.Wrap(err, "[getBalance]:")
		return shim.Error(err.Error())
	}

	balanceAsBytes := t.utils.float64ToBinary(balance)
	return shim.Success(balanceAsBytes)
}

func (t *ChaincodeStruct) increaseBalance(stub shim.ChaincodeStubInterface, args []string) peer.Response {
	logger = shim.NewLogger("increaseBalanceLogger")

	if len(args) != 3 {
		logger.Error("[increaseBalance] Three arguments expected.")
		return shim.Error("[increaseBalance] Three arguments expected.")
	}

	id := args[0]
	amount := args[1]
	requestID := "increase_" + args[2]

	logger.Info("increaseBalance called with amount ", amount)

	isValid, err := t.tokenHelper.validateRequestID(stub, requestID)

	if err != nil {
		err = errors.Wrap(err, "[transfer]")
		return shim.Error(err.Error())
	}

	if !isValid {
		logger.Error("A request with the same id has already been processed")
		return shim.Error("The request has already been processed")
	}

	logger.Info("RequestID validated.")

	logger.Infof("Storing the requestID in the ledger..")
	t.tokenHelper.storeRequestID(stub, requestID)
	logger.Infof("Stored the requestID in the ledger!")

	currentBalance, err := t.tokenHelper.retrieveBalance(stub, id)
	if err != nil {
		err = errors.Wrap(err, "[increaseBalance]")
		return shim.Error(err.Error())
	}

	increaseTokens, err := strconv.ParseFloat(amount, 64)
	if err != nil {
		err = errors.Wrap(err, "[increaseBalance]")
		return shim.Error(err.Error())
	}

	newBalance := currentBalance + increaseTokens

	err = t.tokenHelper.saveBalance(stub, id, newBalance)
	if err != nil {
		err = errors.Wrap(err, "[increaseBalance]")
		return shim.Error(err.Error())
	}

	logger.Info("[increaseBalance]: Successfully set the balance.")

	return shim.Success(nil)
}
