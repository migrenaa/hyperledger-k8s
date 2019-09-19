package main

import (
	"crypto/sha256"
	"encoding/hex"
	"strconv"

	"github.com/hyperledger/fabric/core/chaincode/shim"
)

type IUtil interface {
	getKey(ccID string, id string) string
	hasValue(stub shim.ChaincodeStubInterface, key string) (bool, error)
	stringToSHA256HexString(toHash string) string
	getStringValue(stub shim.ChaincodeStubInterface, key string) (string, error)
	setStringValue(stub shim.ChaincodeStubInterface, key string, value string) error
	float64ToBinary(number float64) []byte
	binaryToFloat64(number []byte) (float64, error)
}
type Util struct {
}

func (u Util) getKey(ccID string, id string) string {
	return ccID + "_" + id
}

func (u Util) hasValue(stub shim.ChaincodeStubInterface, key string) (bool, error) {
	value, err := u.getStringValue(stub, key)
	if err != nil {
		return false, err
	}
	return len(value) > 0, nil
}

func (u Util) stringToSHA256HexString(toHash string) string {
	hashBytes := sha256.Sum256([]byte(toHash))
	return hex.EncodeToString(hashBytes[:])
}

func (u Util) getStringValue(stub shim.ChaincodeStubInterface, key string) (string, error) {
	hashedValue, err := stub.GetState(key)
	if err != nil {
		return "", err
	}
	return string(hashedValue), nil
}

func (u Util) setStringValue(stub shim.ChaincodeStubInterface, key string, value string) error {
	err := stub.PutState(key, []byte(value))
	if err != nil {
		return err
	}

	return nil
}

func (u Util) float64ToBinary(number float64) []byte {
	numberAsString := strconv.FormatFloat(number, 'f', -1, 64)
	numberAsBytes := []byte(numberAsString)
	return numberAsBytes
}

func (u Util) binaryToFloat64(number []byte) (float64, error) {
	numberAsString := string(number)
	numberAsFloat, err := strconv.ParseFloat(numberAsString, 64)
	if err != nil {
		logger.Error("Error parsing byte array to float")
		logger.Error(err)
		return 0, err
	}
	return numberAsFloat, nil
}
