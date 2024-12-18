ALICE="~/dharitri-sdk/testwallets/latest/users/alice.pem"
BOB="~/dharitri-sdk/testwallets/latest/users/bob.pem"
ADDRESS=$(mxpy data load --key=address-testnet-rewa-dcdt-swap)
DEPLOY_TRANSACTION=$(mxpy data load --key=deployTransaction-testnet)
PROXY=https://testnet-gateway.dharitri.com
CHAIN_ID=T

DCDT_SYSTEM_SC_ADDRESS=moa1qqqqqqqqqqqqqqqpqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqzllls29jpxv

deploy() {
    ######################################################################
    ############################ Update after issue ######################
    ######################################################################
    local WRAPPED_REWA_TOKEN_ID=0x

    mxpy --verbose contract deploy --project=${PROJECT} --recall-nonce --pem=${ALICE} \
    --gas-limit=100000000 \
    --arguments ${WRAPPED_REWA_TOKEN_ID} \
    --send --outfile="deploy-testnet.interaction.json" --proxy=${PROXY} --chain=${CHAIN_ID} || return

    TRANSACTION=$(mxpy data parse --file="deploy-testnet.interaction.json" --expression="data['emittedTransactionHash']")
    ADDRESS=$(mxpy data parse --file="deploy-testnet.interaction.json" --expression="data['contractAddress']")

    mxpy data store --key=address-testnet --value=${ADDRESS}
    mxpy data store --key=deployTransaction-testnet-rewa-dcdt-swap --value=${TRANSACTION}

    echo ""
    echo "Smart contract address: ${ADDRESS}"
}

upgrade() {
    mxpy --verbose contract upgrade ${ADDRESS} --project=${PROJECT} --recall-nonce --pem=${ALICE} \
    --arguments ${WRAPPED_REWA_TOKEN_ID} --gas-limit=100000000 --outfile="upgrade.json" \
    --send --proxy=${PROXY} --chain=${CHAIN_ID} || return
}

issueWrappedRewa() {
    local TOKEN_DISPLAY_NAME=0x5772617070656452657761  # "WrappedRewa"
    local TOKEN_TICKER=0x5745474c44  # "WREWA"
    local INITIAL_SUPPLY=0x01 # 1
    local NR_DECIMALS=0x12 # 18
    local CAN_ADD_SPECIAL_ROLES=0x63616e4164645370656369616c526f6c6573 # "canAddSpecialRoles"
    local TRUE=0x74727565 # "true"

    mxpy --verbose contract call ${DCDT_SYSTEM_SC_ADDRESS} --recall-nonce --pem=${ALICE} \
    --gas-limit=60000000 --value=5000000000000000000 --function="issue" \
    --arguments ${TOKEN_DISPLAY_NAME} ${TOKEN_TICKER} ${INITIAL_SUPPLY} ${NR_DECIMALS} ${CAN_ADD_SPECIAL_ROLES} ${TRUE} \
    --send --proxy=${PROXY} --chain=${CHAIN_ID}
}

setLocalRoles() {
    local LOCAL_MINT_ROLE=0x44434454526f6c654c6f63616c4d696e74 # "DCDTRoleLocalMint"
    local LOCAL_BURN_ROLE=0x44434454526f6c654c6f63616c4275726e # "DCDTRoleLocalBurn"
    local ADDRESS_HEX = $(mxpy wallet bech32 --decode ${ADDRESS})

    mxpy --verbose contract call ${DCDT_SYSTEM_SC_ADDRESS} --recall-nonce --pem=${ALICE} \
    --gas-limit=60000000 --function="setSpecialRole" \
    --arguments ${WRAPPED_REWA_TOKEN_ID} ${ADDRESS_HEX} ${LOCAL_MINT_ROLE} ${LOCAL_BURN_ROLE} \
    --send --proxy=${PROXY} --chain=${CHAIN_ID}
}

wrapRewaBob() {
    mxpy --verbose contract call ${ADDRESS} --recall-nonce --pem=${BOB} \
    --gas-limit=10000000 --value=1000 --function="wrapRewa" \
    --send --proxy=${PROXY} --chain=${CHAIN_ID}
}

unwrapRewaBob() {
    local UNWRAP_REWA_ENDPOINT=0x756e7772617052657761 # "unwrapRewa"
    local UNWRAP_AMOUNT=0x05

    getWrappedRewaTokenIdentifier
    mxpy --verbose contract call ${ADDRESS} --recall-nonce --pem=${BOB} \
    --gas-limit=10000000 --function="DCDTTransfer" \
    --arguments ${TOKEN_IDENTIFIER} ${UNWRAP_AMOUNT} ${UNWRAP_REWA_ENDPOINT} \
    --send --proxy=${PROXY} --chain=${CHAIN_ID}
}

# views

getWrappedRewaTokenIdentifier() {
    local QUERY_OUTPUT=$(mxpy --verbose contract query ${ADDRESS} --function="getWrappedRewaTokenId" --proxy=${PROXY})
    TOKEN_IDENTIFIER=0x$(jq -r '.[0] .hex' <<< "${QUERY_OUTPUT}")
    echo "Wrapped rEWA token identifier: ${TOKEN_IDENTIFIER}"
}

getLockedRewaBalance() {
    mxpy --verbose contract query ${ADDRESS} --function="getLockedRewaBalance" --proxy=${PROXY}
}