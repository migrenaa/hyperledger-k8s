package main

import (
	"strconv"

	"github.com/pkg/errors"

	"github.com/hyperledger/fabric/core/chaincode/shim"
	"github.com/hyperledger/fabric/protos/peer"
)

var logger = shim.NewLogger("chaincodeLogger")

func (t *ChaincodeStruct) transfer(stub shim.ChaincodeStubInterface, args []string) peer.Response {
	if len(args) != 5 {
		return shim.Error("[transfer]: Incorrect args length!")
	}

	requestID := "transfer_" + args[4]
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

	from := args[0]
	to := args[1]
	logger.Info("From: ", from)
	logger.Info("To: ", to)

	value, err := strconv.ParseFloat(args[2], 64)
	if err != nil {
		err = errors.Wrap(err, "[parseTransfer]")
		return shim.Error(err.Error())
	}

	logger.Infof("To ", to)
	logger.Infof("From ", from)
	logger.Infof("Amount ", value)

	securityCode := args[3]
	err = t.tokenHelper.validateSecurityCode(stub, from, securityCode)

	if err != nil {
		err = errors.Wrap(err, "[transfer]: Error verifying the security code of the user")
		return shim.Error(err.Error())
	}

	logger.Infof("Security code verifyied.")

	fromBalance, err := t.tokenHelper.retrieveBalance(stub, from)
	if err != nil {
		err = errors.Wrap(err, "[transfer]: Error getting transaction sender balance")
		return shim.Error(err.Error())
	}

	logger.Infof("From balance %v", fromBalance)

	toBalance, err := t.tokenHelper.retrieveBalance(stub, to)
	if err != nil {
		err = errors.Wrap(err, "[transfer]: Error getting transaction receiver balance")
		return shim.Error(err.Error())
	}

	logger.Infof("To balance %v", toBalance)

	err = validateTransfer(stub, value, fromBalance, toBalance)
	if err != nil {
		err = errors.Wrap(err, "[transfer]")
		return shim.Error(err.Error())
	}

	err = t.tokenHelper.executeTransfer(stub, from, to, value, fromBalance, toBalance)
	if err != nil {
		err = errors.Wrap(err, "[transfer]")
		return shim.Error(err.Error())
	}

	return shim.Success(nil)
}

func validateTransfer(stub shim.ChaincodeStubInterface,
	value float64,
	fromBalance float64,
	toBalance float64,
) error {

	if fromBalance < value {
		return errors.New("[validateTransfer]: The balance in the transfer is bigger than the sender`s Balance")
	}

	return nil
}
