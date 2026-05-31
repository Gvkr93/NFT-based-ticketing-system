-include .env

.PHONY: all test clean deploy deploy-sepolia install build format anvil fund buy list

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
# Anvil's second account — use as buyer to simulate different users
BUYER_ANVIL_KEY  := 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d

all: clean install update build

# ── repo management ───────────────────────────────────────
clean:
	forge clean

remove:
	rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install:
	forge install OpenZeppelin/openzeppelin-contracts --no-commit && \
	forge install foundry-rs/forge-std@v1.8.2 --no-commit && \
	forge install cyfrin/foundry-devops@0.2.2 --no-commit

update:
	forge update

# ── build + test ──────────────────────────────────────────
build:
	forge build

test:
	forge test -v

snapshot:
	forge snapshot

format:
	forge fmt

# ── local chain ───────────────────────────────────────────
anvil:
	anvil -m 'test test test test test test test test test test test junk' \
	--steps-tracing \
	--block-time 1

# ── network args ──────────────────────────────────────────
NETWORK_ARGS := --rpc-url http://localhost:8545 \
                --private-key $(DEFAULT_ANVIL_KEY) \
                --broadcast

ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) \
	                --account $(ACCOUNT) \
	                --broadcast \
	                --verify \
	                --etherscan-api-key $(ETHERSCAN_API_KEY) \
	                -vvvv
endif

# ── deploy ────────────────────────────────────────────────
deploy:
	@forge script script/DeployTicket.s.sol:DeployTicketing $(NETWORK_ARGS)

deploy-sepolia:
	@forge script script/DeployTicket.s.sol:DeployTicketing $(NETWORK_ARGS)

# ── interactions ──────────────────────────────────────────
# organiser creates an event
create-event:
	@forge script script/Interactions.s.sol:CreateEvent \
	--sender $(shell cast wallet address --private-key $(DEFAULT_ANVIL_KEY)) \
	$(NETWORK_ARGS)

# buyer purchases a ticket (uses second anvil account)
buy-ticket:
	@forge script script/Interactions.s.sol:BuyTicket \
	--sender $(shell cast wallet address --private-key $(BUYER_ANVIL_KEY)) \
	--rpc-url http://localhost:8545 \
	--private-key $(BUYER_ANVIL_KEY) \
	--broadcast

# buyer lists ticket for resale
list-resale:
	@forge script script/Interactions.s.sol:ListResale \
	--sender $(shell cast wallet address --private-key $(BUYER_ANVIL_KEY)) \
	--rpc-url http://localhost:8545 \
	--private-key $(BUYER_ANVIL_KEY) \
	--broadcast

# third account buys from resale
buy-resale:
	@forge script script/Interactions.s.sol:BuyResale \
	--sender $(shell cast wallet address --private-key $(DEFAULT_ANVIL_KEY)) \
	$(NETWORK_ARGS)

# read all tickets (no broadcast needed)
get-tickets:
	@forge script script/Interactions.s.sol:GetAllTickets \
	--rpc-url http://localhost:8545

# ── copy ABI to frontend after build ─────────────────────
abi:
	@cp out/Ticketing1155.sol/Ticketing1155.json frontend/constants/Ticketing1155.json
	@echo "ABI copied to frontend"