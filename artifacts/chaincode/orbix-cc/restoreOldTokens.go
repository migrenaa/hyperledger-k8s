package main

import (
	"github.com/pkg/errors"

	"github.com/hyperledger/fabric/core/chaincode/shim"
	"github.com/hyperledger/fabric/protos/peer"
)

func (t *ChaincodeStruct) restoreOldTokens(stub shim.ChaincodeStubInterface, args []string) peer.Response {

	if len(args) != 4 {
		return shim.Error("[restoreOldTokens]: Incorrect args length!")
	}

	userID := args[0]
	oldAccount := args[1]
	restorationCode := args[2]
	securityCode := args[3]

	logger.Info("UserID : ", userID)

	err := t.tokenHelper.validateSecurityCode(stub, userID, securityCode)

	if err != nil {
		err = errors.Wrap(err, "[restoreOldTokens]: Error verifying the security code of the user")
		return shim.Error(err.Error())
	}

	err = t.tokenHelper.verifyRestorationCode(stub, oldAccount, restorationCode)

	if err != nil {
		err = errors.Wrap(err, "[restoreOldTokens]: Error verifying the restoration code of the user")
		return shim.Error(err.Error())
	}

	oldAccountBalance, err := t.tokenHelper.retrieveBalance(stub, oldAccount)
	if err != nil {
		err = errors.Wrap(err, "[restoreOldTokens]: Error getting transaction sender balance")
		return shim.Error(err.Error())
	}

	newAccountBalance, err := t.tokenHelper.retrieveBalance(stub, userID)
	if err != nil {
		err = errors.Wrap(err, "[restoreOldTokens]: Error getting transaction receiver balance")
		return shim.Error(err.Error())
	}

	err = validateTransfer(stub, oldAccountBalance, oldAccountBalance, newAccountBalance)
	if err != nil {
		err = errors.Wrap(err, "[restoreOldTokens]")
		return shim.Error(err.Error())
	}

	err = t.tokenHelper.executeTransfer(stub, oldAccount, userID, oldAccountBalance, oldAccountBalance, newAccountBalance)
	if err != nil {
		err = errors.Wrap(err, "[restoreOldTokens]")
		return shim.Error(err.Error())
	}

	return shim.Success(nil)
}
