#!/bin/bash
# Copyright 2020 Coinbase, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

OS="$(uname)"
case "${OS}" in
    'Linux')
        OS='linux'
        SED_IFLAG=(-i'')
        ;;
    'Darwin')
        OS='macos'
        SED_IFLAG=(-i '')
        ;;
    *)
        echo "Operating system '${OS}' not supported."
        exit 1
        ;;
esac

# Remove existing clienterated code
mkdir -p tmp;
DIRS=( types client server )
IGNORED_FILES=( README.md utils.go utils_test.go )

for dir in "${DIRS[@]}"
do
  rm -rf tmp/*;
  for file in "${IGNORED_FILES[@]}"
  do
    [ -f "${dir:?}"/"${file:?}" ] && mv "${dir:?}"/"${file:?}" tmp;
  done

  rm -rf "${dir:?}"/*;

  for file in "${IGNORED_FILES[@]}"
  do
    [ -f tmp/"${file:?}" ] && mv tmp/"${file:?}" "${dir:?}"/"${file:?}";
  done
done

rm -rf tmp;

# Download spec file from releases
ROSETTA_SPEC_VERSION=v1.4.0
curl -L https://github.com/coinbase/rosetta-specifications/releases/download/${ROSETTA_SPEC_VERSION}/api.json -o api.json;

# Generate client + types code
GENERATOR_VERSION=v4.3.0
docker run --user "$(id -u):$(id -g)" --rm -v "${PWD}":/local \
  openapitools/openapi-generator-cli:${GENERATOR_VERSION} generate \
  -i /local/api.json \
  -g go \
  -t /local/templates/client \
  --additional-properties packageName=client\
  -o /local/client_tmp;

# Remove unnecessary client files
rm -f client_tmp/go.mod;
rm -f client_tmp/README.md;
rm -f client_tmp/go.mod;
rm -f client_tmp/go.sum;
rm -rf client_tmp/api;
rm -rf client_tmp/docs;
rm -f client_tmp/git_push.sh;
rm -f client_tmp/.travis.yml;
rm -f client_tmp/.gitignore;
rm -f client_tmp/.openapi-generator-ignore;
rm -rf client_tmp/.openapi-generator;
mv client_tmp/* client;
rm -rf client_tmp;

# Add server code
docker run --user "$(id -u):$(id -g)" --rm -v "${PWD}":/local \
  openapitools/openapi-generator-cli:${GENERATOR_VERSION} generate \
  -i /local/api.json \
  -g go-server \
  -t /local/templates/server \
  --additional-properties packageName=server\
  -o /local/server_tmp;

# Remove unnecessary server files
rm -rf server_tmp/api;
rm -rf server_tmp/.openapi-generator;
rm -f server_tmp/.openapi-generator-ignore;
rm -f server_tmp/go.mod;
rm -f server_tmp/main.go;
rm -f server_tmp/README.md;
rm -f server_tmp/Dockerfile;
mv server_tmp/go/* server_tmp/.;
rm -rf server_tmp/go;
rm -f server_tmp/model_*.go
rm -f server_tmp/*_service.go
mv server_tmp/* server;
rm -rf server_tmp;

# Remove spec file
rm -f api.json;

# Fix linting issues
sed "${SED_IFLAG[@]}" 's/Api/API/g' client/* server/*;
sed "${SED_IFLAG[@]}" 's/Json/JSON/g' client/* server/*;
sed "${SED_IFLAG[@]}" 's/Id /ID /g' client/* server/*;
sed "${SED_IFLAG[@]}" 's/Url/URL/g' client/* server/*;

# Fix enum pointers
sed "${SED_IFLAG[@]}" 's/*CurveType/CurveType/g' client/* server/*;
sed "${SED_IFLAG[@]}" 's/*SignatureType/SignatureType/g' client/* server/*;

# Fix CurveTypes and SignatureTypes
sed "${SED_IFLAG[@]}" 's/SECP256K1/Secp256k1/g' client/* server/*;
sed "${SED_IFLAG[@]}" 's/EDWARDS25519/Edwards25519/g' client/* server/*;
sed "${SED_IFLAG[@]}" 's/ECDSA_RECOVERY/EcdsaRecovery/g' client/* server/*;
sed "${SED_IFLAG[@]}" 's/ECDSA/Ecdsa/g' client/* server/*;
sed "${SED_IFLAG[@]}" 's/ED25519/Ed25519/g' client/* server/*;

# Remove special characters
sed "${SED_IFLAG[@]}" 's/&#x60;//g' client/* server/*;
sed "${SED_IFLAG[@]}" 's/\&quot;//g' client/* server/*;
sed "${SED_IFLAG[@]}" 's/\&lt;b&gt;//g' client/* server/*;
sed "${SED_IFLAG[@]}" 's/\&lt;\/b&gt;//g' client/* server/*;
sed "${SED_IFLAG[@]}" 's/<code>//g' client/* server/*;
sed "${SED_IFLAG[@]}" 's/<\/code>//g' client/* server/*;

# Fix slice containing pointers
sed "${SED_IFLAG[@]}" 's/\*\[\]/\[\]\*/g' client/* server/*;

# Fix map pointers
sed "${SED_IFLAG[@]}" 's/\*map/map/g' client/* server/*;

# Move model files to types/
mv client/model_*.go types/;
for file in types/model_*.go; do
    mv "$file" "${file/model_/}"
done

# Change model files to correct package
sed "${SED_IFLAG[@]}" 's/package client/package types/g' types/*;

# Format client generated code
FORMAT_GEN="gofmt -w /local/types; gofmt -w /local/client; gofmt -w /local/server"
GOLANG_VERSION=1.13
docker run --rm -v "${PWD}":/local \
  golang:${GOLANG_VERSION} sh -c \
  "cd /local; make deps; ${FORMAT_GEN}; make add-license; make shorten-lines;"
