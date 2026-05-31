// index.js
import { ethers } from "./ethers-6.7.esm.min.js"
import { ABI, CONTRACT_ADDRESSES } from "./constants.js"

// ── get contract address for current network ──────────────
async function getContractAddress() {
    const provider = new ethers.BrowserProvider(window.ethereum)
    const network = await provider.getNetwork()
    const chainId = Number(network.chainId)

    const address = CONTRACT_ADDRESSES[chainId]
    if (!address) throw new Error(`No contract deployed on chain ${chainId}`)
    return address
}

// ── read — no wallet needed ───────────────────────────────
async function getReadContract() {
    const provider = new ethers.BrowserProvider(window.ethereum)
    const address = await getContractAddress()
    return new ethers.Contract(address, ABI, provider)
}

// ── write — needs MetaMask signature ─────────────────────
async function getWriteContract() {
    const provider = new ethers.BrowserProvider(window.ethereum)
    await provider.send("eth_requestAccounts", [])
    const signer = await provider.getSigner()
    const address = await getContractAddress()
    return new ethers.Contract(address, ABI, signer)
}

// ── contract functions ────────────────────────────────────
async function loadTickets() {
    const contract = await getReadContract()
    const tickets = await contract.getAllEventTokens()

    const list = document.getElementById("ticket-list")
    list.innerHTML = ""

    tickets.forEach(t => {
        // uint256 comes back as BigInt — always toString() before rendering
        list.innerHTML += `
            <div class="ticket">
                <p>Token #${t.tokenId.toString()}</p>
                <p>${ethers.formatEther(t.price)} ETH</p>
                <p>${t.currentSupply.toString()} / ${t.maxSupply.toString()} left</p>
                <p>${t.isActive ? "On Sale" : "Sold Out"}</p>
                <button onclick="buyTicket('${t.tokenId}', '${t.price}')">
                    Buy
                </button>
            </div>
        `
    })
}

async function createNewEvent(uri, priceEth, supply) {
    const contract = await getWriteContract()
    const tx = await contract.createEventToken(
        uri,
        ethers.parseEther(priceEth),   // "0.05" string → BigInt wei
        BigInt(supply),
        { value: ethers.parseEther("0.0002") }  // listing fee
    )
    updateStatus("Waiting for confirmation...")
    await tx.wait()
    updateStatus("Event created!")
    loadTickets()
}

async function buyTicket(tokenId, price) {
    const contract = await getWriteContract()
    const tx = await contract.executeSale(
        BigInt(tokenId),
        1n,
        { value: BigInt(price) }  // price is already in wei from the contract
    )
    updateStatus("Waiting for confirmation...")
    await tx.wait()
    updateStatus("Ticket purchased!")
    loadTickets()
}

async function listForResale(tokenId, amount, resalePriceEth) {
    const contract = await getWriteContract()
    const address = await getContractAddress()

    // Transaction 1 — approve
    updateStatus("Approving... (1/2)")
    const approveTx = await contract.setApprovalForAll(address, true)
    await approveTx.wait()

    // Transaction 2 — list
    updateStatus("Listing... (2/2)")
    const listTx = await contract.listForResale(
        BigInt(tokenId),
        BigInt(amount),
        ethers.parseEther(resalePriceEth)
    )
    await listTx.wait()
    updateStatus("Listed for resale!")
    loadTickets()
}

async function buyResaleTicket(listingId, priceEth) {
    const contract = await getWriteContract()
    const tx = await contract.buyResaleTicket(
        BigInt(listingId),
        1n,
        { value: ethers.parseEther(priceEth) }
    )
    updateStatus("Waiting for confirmation...")
    await tx.wait()
    updateStatus("Resale ticket purchased!")
    loadTickets()
}

// ── network switch detection ──────────────────────────────
// If user switches network in MetaMask, reload everything
window.ethereum.on("chainChanged", () => {
    updateStatus("Network changed, reloading...")
    loadTickets()
})

window.ethereum.on("accountsChanged", () => {
    updateStatus("Account changed")
    loadTickets()
})

// ── helpers ───────────────────────────────────────────────
function updateStatus(msg) {
    document.getElementById("status").innerText = msg
    console.log(msg)
}

// expose to HTML onclick handlers
window.buyTicket = buyTicket
window.createNewEvent = createNewEvent
window.listForResale = listForResale
window.buyResaleTicket = buyResaleTicket

// load on startup
loadTickets()