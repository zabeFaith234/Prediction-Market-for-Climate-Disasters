const CONTRACT_ADDRESS = 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM';
const CONTRACT_NAME = 'prediction-market-climate';
const NETWORK = new StacksNetwork.TestnetNetwork();

let userSession = null;
let userData = null;

document.addEventListener('DOMContentLoaded', function() {
    initializeApp();
    setupEventListeners();
    loadInitialData();
});

function initializeApp() {
    const appConfig = new AppConfig(['store_write', 'publish_data']);
    userSession = new UserSession({ appConfig });
    
    if (userSession.isUserSignedIn()) {
        userData = userSession.loadUserData();
        updateUI();
    }
}

function setupEventListeners() {
    document.getElementById('connectBtn').addEventListener('click', connectWallet);
    document.getElementById('createForm').addEventListener('submit', createPrediction);
    document.getElementById('depositBtn').addEventListener('click', depositFunds);
    document.getElementById('withdrawBtn').addEventListener('click', withdrawFunds);
    document.getElementById('closeModal').addEventListener('click', closeModal);
    document.getElementById('betYes').addEventListener('click', () => placeBet(true));
    document.getElementById('betNo').addEventListener('click', () => placeBet(false));
    
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.addEventListener('click', switchTab);
    });
    
    window.addEventListener('click', function(event) {
        const modal = document.getElementById('betModal');
        if (event.target === modal) {
            closeModal();
        }
    });
}

function switchTab(event) {
    const tabId = event.target.dataset.tab;
    
    document.querySelectorAll('.tab-btn').forEach(btn => btn.classList.remove('active'));
    document.querySelectorAll('.tab-panel').forEach(panel => panel.classList.remove('active'));
    
    event.target.classList.add('active');
    document.getElementById(tabId).classList.add('active');
    
    if (tabId === 'predictions') {
        loadPredictions();
    } else if (tabId === 'wallet') {
        loadUserBets();
    }
}

async function connectWallet() {
    try {
        const authResponse = await showConnect({
            appDetails: {
                name: 'Climate Prediction Market',
                icon: window.location.origin + '/icon.png',
            },
            redirectTo: '/',
            onFinish: () => {
                window.location.reload();
            },
            userSession: userSession,
        });
    } catch (error) {
        showToast('Failed to connect wallet', 'error');
    }
}

function updateUI() {
    if (userData) {
        document.getElementById('connectBtn').textContent = 'Connected';
        document.getElementById('connectBtn').disabled = true;
        loadUserBalance();
    }
}

async function loadInitialData() {
    await loadReliefFund();
    await loadPredictions();
}

async function loadReliefFund() {
    try {
        const functionArgs = [];
        const options = {
            contractAddress: CONTRACT_ADDRESS,
            contractName: CONTRACT_NAME,
            functionName: 'get-total-relief-fund',
            functionArgs: functionArgs,
            network: NETWORK,
        };
        
        const result = await callReadOnlyFunction(options);
        const reliefFund = result.value;
        document.getElementById('reliefFund').textContent = (reliefFund / 1000000).toFixed(6);
    } catch (error) {
        console.error('Error loading relief fund:', error);
    }
}

async function loadUserBalance() {
    if (!userData) return;
    
    try {
        const functionArgs = [principalCV(userData.profile.stxAddress.testnet)];
        const options = {
            contractAddress: CONTRACT_ADDRESS,
            contractName: CONTRACT_NAME,
            functionName: 'get-user-balance',
            functionArgs: functionArgs,
            network: NETWORK,
        };
        
        const result = await callReadOnlyFunction(options);
        const balance = result.value;
        document.getElementById('userBalance').textContent = (balance / 1000000).toFixed(6);
    } catch (error) {
        console.error('Error loading user balance:', error);
    }
}

async function loadPredictions() {
    const grid = document.getElementById('predictionsGrid');
    grid.innerHTML = '<div class="loading">Loading predictions...</div>';
    
    try {
        const functionArgs = [];
        const options = {
            contractAddress: CONTRACT_ADDRESS,
            contractName: CONTRACT_NAME,
            functionName: 'get-next-prediction-id',
            functionArgs: functionArgs,
            network: NETWORK,
        };
        
        const result = await callReadOnlyFunction(options);
        const nextId = result.value;
        
        const predictions = [];
        for (let i = 1; i < nextId; i++) {
            const prediction = await loadPrediction(i);
            if (prediction) {
                predictions.push({id: i, ...prediction});
            }
        }
        
        displayPredictions(predictions);
    } catch (error) {
        console.error('Error loading predictions:', error);
        grid.innerHTML = '<div class="loading">Error loading predictions</div>';
    }
}

async function loadPrediction(id) {
    try {
        const functionArgs = [uintCV(id)];
        const options = {
            contractAddress: CONTRACT_ADDRESS,
            contractName: CONTRACT_NAME,
            functionName: 'get-prediction',
            functionArgs: functionArgs,
            network: NETWORK,
        };
        
        const result = await callReadOnlyFunction(options);
        if (result.type === 'some') {
            return result.value;
        }
        return null;
    } catch (error) {
        console.error('Error loading prediction:', error);
        return null;
    }
}

function displayPredictions(predictions) {
    const grid = document.getElementById('predictionsGrid');
    
    if (predictions.length === 0) {
        grid.innerHTML = '<div class="loading">No predictions found</div>';
        return;
    }
    
    grid.innerHTML = predictions.map(prediction => {
        const currentBlock = 1000000;
        const deadline = prediction.deadline;
        const isExpired = currentBlock > deadline;
        const isResolved = prediction.resolved;
        
        let statusClass = 'status-active';
        let statusText = 'Active';
        
        if (isResolved) {
            statusClass = 'status-resolved';
            statusText = 'Resolved';
        } else if (isExpired) {
            statusClass = 'status-expired';
            statusText = 'Expired';
        }
        
        const totalPool = prediction['total-yes-bets'] + prediction['total-no-bets'];
        
        return `
            <div class="prediction-card">
                <div class="status-badge ${statusClass}">${statusText}</div>
                <div class="prediction-header">
                    <h3 class="prediction-title">${prediction.title}</h3>
                    <p class="prediction-description">${prediction.description}</p>
                </div>
                <div class="prediction-stats">
                    <div class="stat-item">
                        <span class="stat-label">Total Pool</span>
                        <span class="stat-value">${(totalPool / 1000000).toFixed(2)} STX</span>
                    </div>
                    <div class="stat-item">
                        <span class="stat-label">Yes Bets</span>
                        <span class="stat-value">${(prediction['total-yes-bets'] / 1000000).toFixed(2)} STX</span>
                    </div>
                    <div class="stat-item">
                        <span class="stat-label">No Bets</span>
                        <span class="stat-value">${(prediction['total-no-bets'] / 1000000).toFixed(2)} STX</span>
                    </div>
                </div>
                ${!isResolved && !isExpired && userData ? `
                    <div class="prediction-actions">
                        <button class="bet-btn yes" onclick="openBetModal(${prediction.id})">Place Bet</button>
                    </div>
                ` : ''}
                ${isResolved ? `
                    <div class="prediction-result">
                        <strong>Result: ${prediction.outcome?.value ? 'Yes' : 'No'}</strong>
                    </div>
                ` : ''}
            </div>
        `;
    }).join('');
}

function openBetModal(predictionId) {
    const modal = document.getElementById('betModal');
    modal.style.display = 'block';
    modal.dataset.predictionId = predictionId;
    
    loadPrediction(predictionId).then(prediction => {
        document.getElementById('predictionDetails').innerHTML = `
            <h4>${prediction.title}</h4>
            <p>${prediction.description}</p>
            <div class="prediction-stats">
                <div class="stat-item">
                    <span class="stat-label">Yes Pool</span>
                    <span class="stat-value">${(prediction['total-yes-bets'] / 1000000).toFixed(2)} STX</span>
                </div>
                <div class="stat-item">
                    <span class="stat-label">No Pool</span>
                    <span class="stat-value">${(prediction['total-no-bets'] / 1000000).toFixed(2)} STX</span>
                </div>
            </div>
        `;
    });
}

function closeModal() {
    const modal = document.getElementById('betModal');
    modal.style.display = 'none';
    document.getElementById('betAmount').value = '';
}

async function placeBet(prediction) {
    const modal = document.getElementById('betModal');
    const predictionId = parseInt(modal.dataset.predictionId);
    const amount = parseFloat(document.getElementById('betAmount').value);
    
    if (!amount || amount <= 0) {
        showToast('Please enter a valid amount', 'error');
        return;
    }
    
    if (!userData) {
        showToast('Please connect your wallet', 'error');
        return;
    }
    
    try {
        const functionArgs = [
            uintCV(predictionId),
            uintCV(Math.floor(amount * 1000000)),
            boolCV(prediction)
        ];
        
        const txOptions = {
            contractAddress: CONTRACT_ADDRESS,
            contractName: CONTRACT_NAME,
            functionName: 'place-bet',
            functionArgs: functionArgs,
            network: NETWORK,
            senderKey: userData.appPrivateKey,
        };
        
        const transaction = await makeContractCall(txOptions);
        const result = await broadcastTransaction(transaction, NETWORK);
        
        showToast('Bet placed successfully!', 'success');
        closeModal();
        setTimeout(() => {
            loadPredictions();
            loadUserBalance();
        }, 2000);
        
    } catch (error) {
        console.error('Error placing bet:', error);
        showToast('Error placing bet', 'error');
    }
}

async function createPrediction(event) {
    event.preventDefault();
    
    if (!userData) {
        showToast('Please connect your wallet', 'error');
        return;
    }
    
    const title = document.getElementById('title').value;
    const description = document.getElementById('description').value;
    const deadline = parseInt(document.getElementById('deadline').value);
    
    try {
        const functionArgs = [
            stringAsciiCV(title),
            stringAsciiCV(description),
            uintCV(deadline)
        ];
        
        const txOptions = {
            contractAddress: CONTRACT_ADDRESS,
            contractName: CONTRACT_NAME,
            functionName: 'create-prediction',
            functionArgs: functionArgs,
            network: NETWORK,
            senderKey: userData.appPrivateKey,
        };
        
        const transaction = await makeContractCall(txOptions);
        const result = await broadcastTransaction(transaction, NETWORK);
        
        showToast('Prediction created successfully!', 'success');
        document.getElementById('createForm').reset();
        
        setTimeout(() => {
            loadPredictions();
        }, 2000);
        
    } catch (error) {
        console.error('Error creating prediction:', error);
        showToast('Error creating prediction', 'error');
    }
}

async function depositFunds() {
    if (!userData) {
        showToast('Please connect your wallet', 'error');
        return;
    }
    
    const amount = parseFloat(document.getElementById('depositAmount').value);
    
    if (!amount || amount <= 0) {
        showToast('Please enter a valid amount', 'error');
        return;
    }
    
    try {
        const functionArgs = [uintCV(Math.floor(amount * 1000000))];
        
        const txOptions = {
            contractAddress: CONTRACT_ADDRESS,
            contractName: CONTRACT_NAME,
            functionName: 'deposit-funds',
            functionArgs: functionArgs,
            network: NETWORK,
            senderKey: userData.appPrivateKey,
        };
        
        const transaction = await makeContractCall(txOptions);
        const result = await broadcastTransaction(transaction, NETWORK);
        
        showToast('Funds deposited successfully!', 'success');
        document.getElementById('depositAmount').value = '';
        
        setTimeout(() => {
            loadUserBalance();
        }, 2000);
        
    } catch (error) {
        console.error('Error depositing funds:', error);
        showToast('Error depositing funds', 'error');
    }
}

async function withdrawFunds() {
    if (!userData) {
        showToast('Please connect your wallet', 'error');
        return;
    }
    
    const amount = parseFloat(document.getElementById('withdrawAmount').value);
    
    if (!amount || amount <= 0) {
        showToast('Please enter a valid amount', 'error');
        return;
    }
    
    try {
        const functionArgs = [uintCV(Math.floor(amount * 1000000))];
        
        const txOptions = {
            contractAddress: CONTRACT_ADDRESS,
            contractName: CONTRACT_NAME,
            functionName: 'withdraw-funds',
            functionArgs: functionArgs,
            network: NETWORK,
            senderKey: userData.appPrivateKey,
        };
        
        const transaction = await makeContractCall(txOptions);
        const result = await broadcastTransaction(transaction, NETWORK);
        
        showToast('Funds withdrawn successfully!', 'success');
        document.getElementById('withdrawAmount').value = '';
        
        setTimeout(() => {
            loadUserBalance();
        }, 2000);
        
    } catch (error) {
        console.error('Error withdrawing funds:', error);
        showToast('Error withdrawing funds', 'error');
    }
}

async function loadUserBets() {
    if (!userData) {
        document.getElementById('userBets').innerHTML = '<div class="loading">Please connect your wallet</div>';
        return;
    }
    
    const betsContainer = document.getElementById('userBets');
    betsContainer.innerHTML = '<div class="loading">Loading your bets...</div>';
    
    try {
        const nextId = await loadNextPredictionId();
        const userBets = [];
        
        for (let i = 1; i < nextId; i++) {
            const bet = await loadUserBet(userData.profile.stxAddress.testnet, i);
            if (bet) {
                const prediction = await loadPrediction(i);
                userBets.push({
                    predictionId: i,
                    bet: bet,
                    prediction: prediction
                });
            }
        }
        
        displayUserBets(userBets);
    } catch (error) {
        console.error('Error loading user bets:', error);
        betsContainer.innerHTML = '<div class="loading">Error loading bets</div>';
    }
}

async function loadNextPredictionId() {
    const functionArgs = [];
    const options = {
        contractAddress: CONTRACT_ADDRESS,
        contractName: CONTRACT_NAME,
        functionName: 'get-next-prediction-id',
        functionArgs: functionArgs,
        network: NETWORK,
    };
    
    const result = await callReadOnlyFunction(options);
    return result.value;
}

async function loadUserBet(userAddress, predictionId) {
    try {
        const functionArgs = [
            principalCV(userAddress),
            uintCV(predictionId)
        ];
        
        const options = {
            contractAddress: CONTRACT_ADDRESS,
            contractName: CONTRACT_NAME,
            functionName: 'get-user-bet',
            functionArgs: functionArgs,
            network: NETWORK,
        };
        
        const result = await callReadOnlyFunction(options);
        if (result.type === 'some') {
            return result.value;
        }
        return null;
    } catch (error) {
        console.error('Error loading user bet:', error);
        return null;
    }
}

function displayUserBets(userBets) {
    const container = document.getElementById('userBets');
    
    if (userBets.length === 0) {
        container.innerHTML = '<div class="loading">No bets found</div>';
        return;
    }
    
    container.innerHTML = userBets.map(({ predictionId, bet, prediction }) => {
        const canClaim = prediction.resolved && 
                        prediction.outcome?.value === bet.prediction &&
                        !bet.claimed;
        
        return `
            <div class="bet-item">
                <div class="bet-info">
                    <h4>${prediction.title}</h4>
                    <p>Bet: ${bet.prediction ? 'Yes' : 'No'}</p>
                    <p class="bet-amount">Amount: ${(bet.amount / 1000000).toFixed(6)} STX</p>
                    <p>Status: ${bet.claimed ? 'Claimed' : (prediction.resolved ? (prediction.outcome?.value === bet.prediction ? 'Won' : 'Lost') : 'Pending')}</p>
                </div>
                ${canClaim ? `
                    <button class="claim-btn" onclick="claimWinnings(${predictionId})">Claim Winnings</button>
                ` : ''}
            </div>
        `;
    }).join('');
}

async function claimWinnings(predictionId) {
    if (!userData) {
        showToast('Please connect your wallet', 'error');
        return;
    }
    
    try {
        const functionArgs = [uintCV(predictionId)];
        
        const txOptions = {
            contractAddress: CONTRACT_ADDRESS,
            contractName: CONTRACT_NAME,
            functionName: 'claim-winnings',
            functionArgs: functionArgs,
            network: NETWORK,
            senderKey: userData.appPrivateKey,
        };
        
        const transaction = await makeContractCall(txOptions);
        const result = await broadcastTransaction(transaction, NETWORK);
        
        showToast('Winnings claimed successfully!', 'success');
        
        setTimeout(() => {
            loadUserBets();
            loadUserBalance();
        }, 2000);
        
    } catch (error) {
        console.error('Error claiming winnings:', error);
        showToast('Error claiming winnings', 'error');
    }
}

function showToast(message, type = 'info') {
    const toast = document.getElementById('toast');
    toast.textContent = message;
    toast.className = `toast ${type}`;
    toast.classList.add('show');
    
    setTimeout(() => {
        toast.classList.remove('show');
    }, 3000);
}

const {
    AppConfig,
    UserSession,
    showConnect,
    openContractCall,
    uintCV,
    stringAsciiCV,
    boolCV,
    principalCV,
    makeContractCall,
    broadcastTransaction,
    callReadOnlyFunction,
    standardPrincipalCV,
    cvToJSON,
    StacksTestnet,
    StacksMainnet,
    StacksNetwork
} = window.StacksConnect;
