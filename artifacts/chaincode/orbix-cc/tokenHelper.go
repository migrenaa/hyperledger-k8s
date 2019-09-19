package main

import (
	"time"

	"github.com/hyperledger/fabric/core/chaincode/shim"
	"github.com/pkg/errors"
)

type ITokenHelperStruct interface {
	validateRequestID(stub shim.ChaincodeStubInterface, requestID string) (bool, error)
	storeRequestID(stub shim.ChaincodeStubInterface, requestID string) error
	validateSecurityCode(stub shim.ChaincodeStubInterface, userID string, securityCode string) error
	verifyRestorationCode(stub shim.ChaincodeStubInterface, userID string, restorationCode string) error
	retrieveBalance(stub shim.ChaincodeStubInterface, userID string) (float64, error)
	saveBalance(stub shim.ChaincodeStubInterface, userID string, balance float64) error
	executeTransfer(stub shim.ChaincodeStubInterface, from string, to string, value float64, fromBalance float64, toBalance float64) error
}
type TokenHelperStruct struct {
	utils IUtil
}

// validateRequestID returns true if the request ID passed has not been processed
func (u TokenHelperStruct) validateRequestID(stub shim.ChaincodeStubInterface, requestID string) (bool, error) {
	res, err := stub.GetState(requestID)
	if err != nil {
		return false, err
	}

	if res == nil {
		return true, nil
	}
	return false, nil
}

// storeRequestID stores a requestID in the ledger with composite key - requestID, current time
func (u TokenHelperStruct) storeRequestID(stub shim.ChaincodeStubInterface, requestID string) error {
	currentTime := time.Now()
	timeAsByte := []byte(currentTime.String())
	err := stub.PutState(requestID, timeAsByte)
	if err != nil {
		return err
	}
	return nil
}

func (u TokenHelperStruct) validateSecurityCode(stub shim.ChaincodeStubInterface, userID string, securityCode string) error {

	logger := shim.NewLogger("authenticateLogger")

	logger.Info("Hashing the code and the UUID")

	hashedCode := u.utils.stringToSHA256HexString(securityCode)
	hashedID := u.utils.stringToSHA256HexString(userID)
	logger.Debugf("Hashed code %s", hashedCode)

	key := u.utils.getKey(SecurityCodeChaincode, hashedID)

	logger.Info("Getting the code from the state of the ledger")
	stateCode, err := u.utils.getStringValue(stub, key)

	//TODO remove this in production
	logger.Debugf("Code from the ledger: %s", stateCode)

	if err != nil {
		logger.Error("Error getting hash from state")
		return err
	}

	if len(stateCode) == 0 {
		logger.Error("Identity not registered")
		return errors.New("Identity not registered")
	}

	logger.Info("Comparing the two codes")

	if hashedCode != stateCode {
		logger.Error("Codes do not match")
		return errors.New("Codes do not match")
	}

	logger.Info("Codes do match")

	return nil
}

func (u TokenHelperStruct) verifyRestorationCode(stub shim.ChaincodeStubInterface, userID string, restorationCode string) error {

	logger := shim.NewLogger("verifyRestorationCode")

	//TODO remove this in production
	logger.Debugf("The UUID: %s", userID)
	logger.Info("Hashing the restoration code and the UUID")

	hashedCode := u.utils.stringToSHA256HexString(restorationCode)
	hashedID := u.utils.stringToSHA256HexString(userID)
	logger.Debugf("Hashed restoration code %s", hashedCode)

	logger.Info("Getting the restoration code from the state of the ledger")
	key := u.utils.getKey(RestorationCodeChaincode, hashedID)
	stateCode, err := u.utils.getStringValue(stub, key)

	//TODO remove this in production
	logger.Debugf("Code from the ledger: %s", stateCode)

	if err != nil {
		logger.Error("Error getting hash restoration code from state")
		return err
	}

	if len(stateCode) == 0 {
		logger.Error("Identity not associated with a restoration code")
		return errors.New("Identity not associated with a restoration code")
	}

	logger.Info("Comparing the two codes")

	if hashedCode != stateCode {
		logger.Error("Restoration Codes do not match")
		return errors.New("Restoration Codes do not match")
	}

	logger.Info("Restoration Codes do match")

	return nil
}

func (u TokenHelperStruct) retrieveBalance(stub shim.ChaincodeStubInterface, userID string) (float64, error) {

	key := u.utils.getKey(TokenChaincode, userID)
	balanceAsBytes, err := stub.GetState(key)

	if err != nil {
		err = errors.Wrap(err, "[retrieveBalance]")
		return 0, err
	}

	if balanceAsBytes == nil {
		err = errors.Wrap(err, "[retrieveBalance]")
		return 0, nil
	}

	balance, err := u.utils.binaryToFloat64(balanceAsBytes)
	if err != nil {
		return 0, errors.Wrap(err, "[retrieveBalance]")
	}

	logger.Infof("Balance %v", balance)
	return balance, nil
}

func (u TokenHelperStruct) saveBalance(stub shim.ChaincodeStubInterface, userID string, balance float64) error {
	balanceAsBytes := u.utils.float64ToBinary(balance)
	key := u.utils.getKey(TokenChaincode, userID)
	err := stub.PutState(key, balanceAsBytes)
	if err != nil {
		err = errors.Wrap(err, "[saveBalance]")
		return err
	}

	return nil
}

func (u TokenHelperStruct) executeTransfer(stub shim.ChaincodeStubInterface,
	from string,
	to string,
	value float64,
	fromBalance float64,
	toBalance float64) error {

	fromBalance -= value
	toBalance += value

	err := u.saveBalance(stub, from, fromBalance)
	if err != nil {
		err = errors.Wrap(err, "[updateBalances] Error changing sender balance")
		return errors.New("Error changing sender balance")
	}
	err = u.saveBalance(stub, to, toBalance)
	if err != nil {
		err = errors.Wrap(err, "[updateBalances] Error receiver sender balance")
		return err
	}
	return nil
}
