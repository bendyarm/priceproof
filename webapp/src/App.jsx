import { useState, useEffect } from "react";
import aleoLogo from "./assets/aleo.svg";
import "./App.css";
import helloworld_program from "../helloworld/build/main.aleo?raw";
import { AleoWorker } from "./workers/AleoWorker.js";
import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid } from 'recharts';

const aleoWorker = AleoWorker();

function App() {
  const [privateKey, setPrivateKey] = useState("");
  const [showKey, setShowKey] = useState(false);
  const [executing, setExecuting] = useState(false);
  const [deploying, setDeploying] = useState(false);
  const [betAmount, setBetAmount] = useState("1");
  const [showAdvanced, setShowAdvanced] = useState(false);
  const [bullStats, setBullStats] = useState({ uniqueBettors: 0, volume: 0 });
  const [bearStats, setBearStats] = useState({ uniqueBettors: 0, volume: 0 });
  const [programName, setProgramName] = useState("price_proof_test_11.aleo");
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);
  const [aleoPriceHistory, setAleoPriceHistory] = useState([]);

  useEffect(() => {
    // Fetch Aleo price history
    fetch("https://api.coingecko.com/api/v3/coins/aleo/market_chart?vs_currency=usd&days=60&interval=daily")
      .then(res => res.json())
      .then(data => setAleoPriceHistory(data.prices || []));
  }, []);

  useEffect(() => {
    const fetchStats = async () => {
      try {
        setIsLoading(true);
        setError(null);

        // Fetch bull bets
        const bullResponse = await fetch(`https://api.testnet.aleoscan.io/v2/mapping/list_program_mapping_values/${programName}/bull_bets`);
        const bullData = await bullResponse.json();
        
        // Fetch bear bets
        const bearResponse = await fetch(`https://api.testnet.aleoscan.io/v2/mapping/list_program_mapping_values/${programName}/bear_bets`);
        const bearData = await bearResponse.json();

        // Calculate bull stats
        let bullVolume = 0;
        if (!bullData.error && bullData.result) {
          bullVolume = bullData.result.reduce((sum, item) => {
            const value = parseInt(item.value.replace('u64', ''));
            return sum + value;
          }, 0);
        }

        // Calculate bear stats
        let bearVolume = 0;
        if (!bearData.error && bearData.result) {
          bearVolume = bearData.result.reduce((sum, item) => {
            const value = parseInt(item.value.replace('u64', ''));
            return sum + value;
          }, 0);
        }

        setBullStats({
          uniqueBettors: bullData.error ? 0 : bullData.result?.length || 0,
          volume: bullVolume
        });

        setBearStats({
          uniqueBettors: bearData.error ? 0 : bearData.result?.length || 0,
          volume: bearVolume
        });

      } catch (error) {
        // Only log unexpected errors (not 404s)
        if (!error.message?.includes('404')) {
          console.error('Unexpected error fetching stats:', error);
        }
        setBullStats({ uniqueBettors: 0, volume: 0 });
        setBearStats({ uniqueBettors: 0, volume: 0 });
        setError(error.message);
      } finally {
        setIsLoading(false);
      }
    };

    // Initial fetch
    fetchStats();

    // Set up polling every 7 seconds
    const intervalId = setInterval(fetchStats, 7000);

    // Cleanup interval on component unmount
    return () => clearInterval(intervalId);
  }, [programName]);

  const generateAccount = async () => {
    const key = await aleoWorker.getPrivateKey();
    setPrivateKey(await key.to_string());
  };

  async function execute() {
    setExecuting(true);
    var [result_tx] = await aleoWorker.localProgramExecution(
      helloworld_program,
      "initialize_market",
      [
        "2500u64",
      ],
      privateKey,
    );
    setExecuting(false);

    console.log("Execution Response:");
    console.log(result_tx);
  }

  async function execute_place_bet(isYes) {
    console.log("in execute_place_bet");
    setExecuting(true);
    var [result_tx] = await aleoWorker.localProgramExecution(
      helloworld_program,
      "place_bet",
      [
        `${betAmount}u64`,
        isYes ? "true" : "false",
      ],
      privateKey,
    );
    setExecuting(false);

    console.log("Execution Response:");
    console.log(result_tx);
  }

  async function deploy() {
    setDeploying(true);
    try {
      const result = await aleoWorker.deployProgram(helloworld_program, privateKey);
      console.log("Transaction:")
      console.log("https://explorer.provable.com/transaction/" + result)
      alert("Transaction ID: " + result);
    } catch (e) {
      console.log(e)
      alert("Error with deployment, please check console for details");
    }
    setDeploying(false);
  }

  return (
    <div className="app-container">
      <header className="app-header explorer-header">
        <div className="header-left">
          <img src={aleoLogo} className="logo" alt="Aleo logo" />
          <span className="explorer-title">PriceProof</span>
        </div>
        <div className="header-right">
          <input
            type={showKey ? "text" : "password"}
            className="private-key-input"
            placeholder="Enter your private key"
            value={privateKey}
            onChange={e => setPrivateKey(e.target.value)}
            autoComplete="off"
          />
          <button className="show-key-btn" onClick={() => setShowKey(v => !v)}>
            {showKey ? "Hide" : "Show"}
          </button>
        </div>
      </header>

      <main className="market-container">
        <div className="dashboard-grid">
          <div className="dashboard-card price-chart-card">
            <h3>Aleo Price (60d)</h3>
            {aleoPriceHistory.length > 0 ? (
              <ResponsiveContainer width="100%" height={220}>
                <LineChart data={aleoPriceHistory.map(([ts, price]) => ({
                  date: new Date(ts).toLocaleDateString(),
                  price: price
                }))} margin={{ top: 10, right: 20, left: 0, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
                  <XAxis dataKey="date" tick={{ fontSize: 12 }} minTickGap={15} />
                  <YAxis domain={['auto', 'auto']} tick={{ fontSize: 12 }} width={60} />
                  <Tooltip formatter={v => `$${v.toFixed(4)}`} labelStyle={{ fontWeight: 600 }} />
                  <Line type="monotone" dataKey="price" stroke="#6366f1" strokeWidth={2.5} dot={false} />
                </LineChart>
              </ResponsiveContainer>
            ) : (
              <div id="aleo-price-chart-placeholder" style={{height: 220, width: '100%', background: '#f3f4f6', borderRadius: 12, display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#aaa'}}>Chart Loading...</div>
            )}
          </div>
          <div className="dashboard-card stats-card">
            <h3>Market Stats</h3>
            <div className="market-stats-list">
              <div className="stat-row"><span className="stat-label">Bull Bettors</span><span className="stat-value">{isLoading ? 'Loading...' : bullStats.uniqueBettors}</span></div>
              <div className="stat-row"><span className="stat-label">Bull Volume</span><span className="stat-value">{isLoading ? 'Loading...' : bullStats.volume}</span></div>
              <div className="stat-row"><span className="stat-label">Bear Bettors</span><span className="stat-value">{isLoading ? 'Loading...' : bearStats.uniqueBettors}</span></div>
              <div className="stat-row"><span className="stat-label">Bear Volume</span><span className="stat-value">{isLoading ? 'Loading...' : bearStats.volume}</span></div>
            </div>
          </div>
        </div>

        <div className="market-card">
          <div className="market-header">
            <h2>Will Aleo reach $.30 by the end of May 2025?</h2>
          </div>
          <div className="betting-interface">
            <div className="bet-amount-input">
              <label htmlFor="betAmount">Bet Amount (ALEO)</label>
              <div className="input-group">
                <input
                  id="betAmount"
                  type="number"
                  min="1"
                  value={betAmount}
                  onChange={(e) => setBetAmount(e.target.value)}
                  className="bet-input"
                />
                <div className="quick-amounts">
                  <button onClick={() => setBetAmount("5")}>5</button>
                  <button onClick={() => setBetAmount("10")}>10</button>
                  <button onClick={() => setBetAmount("50")}>50</button>
                </div>
              </div>
            </div>
            <div className="bet-buttons">
              <button className="bet-button yes" disabled={executing} onClick={() => execute_place_bet(true)}>Bet YES</button>
              <button className="bet-button no" disabled={executing} onClick={() => execute_place_bet(false)}>Bet NO</button>
            </div>
            <button className="claim-reward-btn" disabled>Claim reward</button>
          </div>
        </div>
        <div className="advanced-section">
          <button 
            className="toggle-advanced"
            onClick={() => setShowAdvanced(!showAdvanced)}
          >
            {showAdvanced ? "Hide Advanced Options" : "Show Advanced Options"}
          </button>
          {showAdvanced && (
            <div className="advanced-options">
              <h3>Market Administration</h3>
              <div className="admin-actions">
                <button 
                  className="admin-button"
                  disabled={deploying} 
                  onClick={deploy}
                >
                  {deploying ? "Deploying..." : "Deploy New Market"}
                </button>
                <button 
                  className="admin-button"
                  disabled={executing} 
                  onClick={execute}
                >
                  {executing ? "Executing..." : "Initialize Market"}
                </button>
              </div>
            </div>
          )}
        </div>
      </main>

      <footer className="app-footer">
        <div className="footer-content">
          <span>Powered by Provable</span>
        </div>
      </footer>
    </div>
  );
}

export default App;

