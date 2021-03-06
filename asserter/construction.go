// Copyright 2020 Coinbase, Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package asserter

import (
	"encoding/hex"
	"errors"
	"fmt"

	"github.com/coinbase/rosetta-sdk-go/types"
)

// ConstructionMetadata returns an error if
// the metadata is not a JSON object.
func ConstructionMetadata(
	response *types.ConstructionMetadataResponse,
) error {
	if response.Metadata == nil {
		return errors.New("Metadata is nil")
	}

	return nil
}

// ConstructionSubmit returns an error if
// the types.TransactionIdentifier in the response is not
// valid or if the Submission.Status is not contained
// within the provided validStatuses slice.
func ConstructionSubmit(
	response *types.ConstructionSubmitResponse,
) error {
	if err := TransactionIdentifier(response.TransactionIdentifier); err != nil {
		return err
	}

	return nil
}

// PublicKey returns an error if
// the *types.PublicKey is nil, is not
// valid hex, or has an undefined CurveType.
func PublicKey(
	publicKey *types.PublicKey,
) error {
	if publicKey == nil {
		return errors.New("PublicKey cannot be nil")
	}

	if err := checkHex(publicKey.HexBytes); err != nil {
		return fmt.Errorf("%w public key does not have valid hex", err)
	}

	if err := CurveType(publicKey.CurveType); err != nil {
		return fmt.Errorf("%w public key curve type is not supported", err)
	}

	return nil
}

// CurveType returns an error if
// the curve is not a valid types.CurveType.
func CurveType(
	curve types.CurveType,
) error {
	switch curve {
	case types.Secp256k1, types.Edwards25519:
		return nil
	default:
		return fmt.Errorf("%s is not a supported CurveType", curve)
	}
}

// checkHex returns an error if a
// string is not valid hex or if
// it is empty.
func checkHex(
	hexString string,
) error {
	if len(hexString) == 0 {
		return errors.New("hex string cannot be empty")
	}

	_, err := hex.DecodeString(hexString)
	if err != nil {
		return fmt.Errorf("%w: %s is not a valid hex string", err, hexString)
	}

	return nil
}

// SigningPayload returns an error
// if a *types.SigningPayload is nil,
// has an empty address, has invlaid hex,
// or has an invalid SignatureType (if populated).
func SigningPayload(
	signingPayload *types.SigningPayload,
) error {
	if signingPayload == nil {
		return errors.New("signing payload cannot be nil")
	}

	if len(signingPayload.Address) == 0 {
		return errors.New("signing payload address cannot be empty")
	}

	if err := checkHex(signingPayload.HexBytes); err != nil {
		return fmt.Errorf("%w signature payload is not a valid hex string", err)
	}

	// SignatureType can be optionally populated
	if len(signingPayload.SignatureType) == 0 {
		return nil
	}

	if err := SignatureType(signingPayload.SignatureType); err != nil {
		return fmt.Errorf("%w signature payload signature type is not valid", err)
	}

	return nil
}

// Signatures returns an error if any
// *types.Signature is invalid.
func Signatures(
	signatures []*types.Signature,
) error {
	if len(signatures) == 0 {
		return errors.New("signatures cannot be empty")
	}

	for i, signature := range signatures {
		if err := SigningPayload(signature.SigningPayload); err != nil {
			return fmt.Errorf("%w: signature %d has invalid signing payload", err, i)
		}

		if err := PublicKey(signature.PublicKey); err != nil {
			return fmt.Errorf("%w: signature %d has invalid public key", err, i)
		}

		if err := SignatureType(signature.SignatureType); err != nil {
			return fmt.Errorf("%w: signature %d has invalid signature type", err, i)
		}

		// Return an error if the requested signature type does not match the
		// signture type in the returned signature.
		if len(signature.SigningPayload.SignatureType) > 0 &&
			signature.SigningPayload.SignatureType != signature.SignatureType {
			return fmt.Errorf("requested signature type does not match returned signature type")
		}

		if err := checkHex(signature.HexBytes); err != nil {
			return fmt.Errorf("%w: signature %d has invalid hex", err, i)
		}
	}

	return nil
}

// SignatureType returns an error if
// signature is not a valid types.SignatureType.
func SignatureType(
	signature types.SignatureType,
) error {
	switch signature {
	case types.Ecdsa, types.EcdsaRecovery, types.Ed25519:
		return nil
	default:
		return fmt.Errorf("%s is not a supported SignatureType", signature)
	}
}
