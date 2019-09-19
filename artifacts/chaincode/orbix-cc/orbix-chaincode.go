package main

import (
	"fmt"
	"runtime/debug"

	"github.com/hyperledger/fabric/core/chaincode/shim"
	"github.com/hyperledger/fabric/protos/peer"
)

type ChaincodeStruct struct {
	utils       IUtil
	tokenHelper ITokenHelperStruct
}

// Init is called during chaincode instantiation to initialize any
// data. Note that chaincode upgrade also calls this function to reset
// or to migrate data.
func (cc *ChaincodeStruct) Init(stub shim.ChaincodeStubInterface) peer.Response {
	logger := shim.NewLogger("initLogger")
	logger.Info("Initiating chaincode")
	return shim.Success(nil)
}

// Invoke is called per transaction on the chaincode. Each transaction is
// either a 'get' or a 'set' on the asset created by Init function. The Set
// method may create a new asset by specifying a new key-value pair.
func (cc *ChaincodeStruct) Invoke(stub shim.ChaincodeStubInterface) (res peer.Response) {
	// Handle panic and alter the response to 500 including panic msg
	defer func() {
		if r := recover(); r != nil {
			n := debug.Stack()
			stack := string(n[:])
			res = shim.Error(fmt.Sprintf("the invocation resulted in panic: %+v \n %+v", r, stack))
		}
	}()
	logger := shim.NewLogger("invokeLogger")

	fn, args := stub.GetFunctionAndParameters()

	logger.Debug("Inovking %s chaincode with arguments %v", fn, args)

	switch fn {
	case "storeRestorationCode":
		return cc.storeRestorationCode(stub, args)
	case "registerSecurityCode":
		return cc.storeSecurityCode(stub, args)
	case "validateSecurityCode":
		return cc.validateSecurityCode(stub, args)
	case "hasSecurityCode":
		return cc.hasSecurityCode(stub, args)
	case "getBalance":
		return cc.getBalance(stub, args)
	case "increaseBalance":
		return cc.increaseBalance(stub, args)
	case "transfer":
		return cc.transfer(stub, args)
	case "restoreOldTokens":
		return cc.restoreOldTokens(stub, args)
	}

	return shim.Error("Undefined chaincode function")
}

// main function starts up the chaincode in the container during instantiate
func main() {
	logger := shim.NewLogger("mainLogger")
	util := new(Util)
	tokenHelper := TokenHelperStruct{utils: util}
	chaincodeStruct := ChaincodeStruct{utils: util, tokenHelper: tokenHelper}
	if err := shim.Start(&chaincodeStruct); err != nil {
		logger.Error("Error starting RestorationCodeChaincode")
	}
}
