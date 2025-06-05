#!/bin/bash
# Options Dashboard - Komplettes Setup Script
# Dieses Script erstellt alle benötigten Dateien auf einmal

echo "📦 Erstelle Options Dashboard Dateien..."

# index.html
cat > index.html << 'EOF'
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Options Dashboard</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: system-ui, -apple-system, sans-serif;
            background: #0a0a0a;
            color: #e0e0e0;
            padding: 20px;
            min-height: 100vh;
        }
        
        .container {
            max-width: 900px;
            margin: 0 auto;
        }
        
        h1 {
            text-align: center;
            margin-bottom: 30px;
            color: #fff;
        }
        
        .ticker-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
            gap: 20px;
        }
        
        .ticker-card {
            background: #1a1a1a;
            border-radius: 12px;
            padding: 15px;
            border: 1px solid #333;
            opacity: 0;
            transform: translateY(20px);
            transition: opacity 0.3s, transform 0.3s;
        }
        
        .ticker-card.visible {
            opacity: 1;
            transform: translateY(0);
        }
        
        .ticker-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 10px;
            padding: 10px;
            background: #252525;
            border-radius: 8px;
        }
        
        .ticker-symbol {
            font-size: 1.2em;
            font-weight: bold;
            color: #4a9eff;
        }
        
        .ticker-price {
            font-size: 1.1em;
            color: #fff;
        }
        
        .ticker-stats {
            display: flex;
            gap: 15px;
            padding: 10px;
            background: #252525;
            border-radius: 8px;
            margin-bottom: 10px;
            font-size: 0.9em;
        }
        
        .stat-item {
            display: flex;
            flex-direction: column;
        }
        
        .stat-label {
            color: #888;
            font-size: 0.85em;
        }
        
        .stat-value {
            color: #fff;
            font-weight: 500;
        }
        
        .widget-container {
            height: 260px;
            border-radius: 8px;
            overflow: hidden;
        }
        
        .error {
            color: #ff6b6b;
            font-size: 0.9em;
        }
        
        .loading {
            color: #888;
            font-size: 0.9em;
        }
        
        .last-update {
            text-align: center;
            color: #666;
            font-size: 0.85em;
            margin-top: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Options Dashboard</h1>
        <div id="ticker-grid" class="ticker-grid"></div>
        <div id="last-update" class="last-update"></div>
    </div>

    <script type="module">
        let tickers = [];
        let maxPainData = {};
        const REFRESH_INTERVAL = 60000; // 60 Sekunden
        
        // Yahoo Finance API mit Fallback
        async function fetchQuote(symbol) {
            const timeout = 5000;
            const controller = new AbortController();
            const timeoutId = setTimeout(() => controller.abort(), timeout);
            
            const endpoints = [
                `https://query1.finance.yahoo.com/v7/finance/quote?symbols=${symbol}`,
                `https://query2.finance.yahoo.com/v7/finance/quote?symbols=${symbol}`
            ];
            
            for (const endpoint of endpoints) {
                try {
                    const response = await fetch(endpoint, { signal: controller.signal });
                    clearTimeout(timeoutId);
                    
                    if (!response.ok) continue;
                    
                    const data = await response.json();
                    const quote = data.quoteResponse?.result?.[0];
                    
                    if (quote) {
                        return {
                            price: quote.regularMarketPrice || quote.postMarketPrice || null,
                            change: quote.regularMarketChange || null,
                            changePercent: quote.regularMarketChangePercent || null
                        };
                    }
                } catch (error) {
                    console.error(`Fehler bei ${endpoint}:`, error);
                }
            }
            
            return null;
        }
        
        // Max Pain Daten laden
        async function loadMaxPainData() {
            try {
                const response = await fetch('maxpain.json');
                if (response.ok) {
                    maxPainData = await response.json();
                }
            } catch (error) {
                console.error('Max Pain Daten konnten nicht geladen werden:', error);
            }
        }
        
        // Ticker Card erstellen
        function createTickerCard(ticker) {
            const card = document.createElement('div');
            card.className = 'ticker-card';
            card.dataset.ticker = ticker;
            
            card.innerHTML = `
                <div class="ticker-header">
                    <span class="ticker-symbol">${ticker}</span>
                    <span class="ticker-price loading">Lädt...</span>
                </div>
                <div class="ticker-stats">
                    <div class="stat-item">
                        <span class="stat-label">Änderung</span>
                        <span class="stat-value ticker-change">-</span>
                    </div>
                    <div class="stat-item" style="display: ${maxPainData[ticker] ? 'block' : 'none'}">
                        <span class="stat-label">Max Pain</span>
                        <span class="stat-value ticker-maxpain">${maxPainData[ticker] ? '$' + maxPainData[ticker].toFixed(2) : '-'}</span>
                    </div>
                </div>
                <div class="widget-container" id="widget-${ticker}"></div>
            `;
            
            return card;
        }
        
        // TradingView Widget laden (mit Intersection Observer)
        function loadTradingViewWidget(ticker, container) {
            const script = document.createElement('script');
            script.src = 'https://s3.tradingview.com/external-embedding/embed-widget-symbol-overview.js';
            script.async = true;
            script.innerHTML = JSON.stringify({
                "symbol": ticker,
                "width": "100%",
                "height": 260,
                "locale": "de_DE",
                "dateRange": "1D",
                "colorTheme": "dark",
                "isTransparent": true,
                "autosize": false,
                "largeChartUrl": ""
            });
            
            container.appendChild(script);
        }
        
        // Intersection Observer für Lazy Loading
        const observerOptions = {
            root: null,
            rootMargin: '100px',
            threshold: 0.1
        };
        
        const widgetObserver = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    const ticker = entry.target.dataset.ticker;
                    const widgetContainer = entry.target.querySelector(`#widget-${ticker}`);
                    
                    if (widgetContainer && widgetContainer.children.length === 0) {
                        loadTradingViewWidget(ticker, widgetContainer);
                    }
                    
                    entry.target.classList.add('visible');
                    widgetObserver.unobserve(entry.target);
                }
            });
        }, observerOptions);
        
        // Kurse aktualisieren
        async function updateQuotes() {
            const updateTime = new Date().toLocaleTimeString('de-DE');
            document.getElementById('last-update').textContent = `Letzte Aktualisierung: ${updateTime}`;
            
            for (const ticker of tickers) {
                const card = document.querySelector(`[data-ticker="${ticker}"]`);
                if (!card) continue;
                
                const priceEl = card.querySelector('.ticker-price');
                const changeEl = card.querySelector('.ticker-change');
                
                const quote = await fetchQuote(ticker);
                
                if (quote && quote.price) {
                    priceEl.textContent = `$${quote.price.toFixed(2)}`;
                    priceEl.classList.remove('loading', 'error');
                    
                    if (quote.change !== null && quote.changePercent !== null) {
                        const sign = quote.change >= 0 ? '+' : '';
                        changeEl.textContent = `${sign}${quote.change.toFixed(2)} (${sign}${quote.changePercent.toFixed(2)}%)`;
                        changeEl.style.color = quote.change >= 0 ? '#4ade80' : '#f87171';
                    }
                } else {
                    priceEl.textContent = 'Daten nicht verfügbar';
                    priceEl.classList.add('error');
                    priceEl.classList.remove('loading');
                    changeEl.textContent = '-';
                }
            }
        }
        
        // Initialisierung
        async function init() {
            try {
                // Ticker laden
                const tickerResponse = await fetch('tickers.json');
                tickers = await tickerResponse.json();
                
                // Max Pain Daten laden
                await loadMaxPainData();
                
                // Grid erstellen
                const grid = document.getElementById('ticker-grid');
                tickers.forEach(ticker => {
                    const card = createTickerCard(ticker);
                    grid.appendChild(card);
                    widgetObserver.observe(card);
                });
                
                // Erste Kursabfrage
                await updateQuotes();
                
                // Automatische Aktualisierung
                setInterval(updateQuotes, REFRESH_INTERVAL);
                
            } catch (error) {
                console.error('Initialisierungsfehler:', error);
            }
        }
        
        // Start
        init();
    </script>
</body>
</html>
EOF

# tickers.json
cat > tickers.json << 'EOF'
["GM","BMY","C","EBAY","GILD","MRNA","MRK","PYPL","CSCO","CVS","AMZN","PINS","PFE","WMT","BAC","ENB","DAL","MGM","CCL","AMD","IONQ","CRSP","VZ","DUK","TSLA"]
EOF

# maxpain.py
cat > maxpain.py << 'EOF'
import json
import yfinance as yf
import pandas as pd

with open('tickers.json', 'r') as f:
    tickers = json.load(f)

max_pain_data = {}

for ticker in tickers:
    try:
        stock = yf.Ticker(ticker)
        expirations = stock.options
        if expirations:
            opt_chain = stock.option_chain(expirations[0])
            calls, puts = opt_chain.calls, opt_chain.puts
            strikes = sorted(set(calls['strike'].tolist() + puts['strike'].tolist()))
            spot = stock.info.get('currentPrice', stock.history(period='1d')['Close'][-1])
            
            min_pain = float('inf')
            max_pain_strike = 0
            
            for strike in strikes:
                call_oi = calls[calls['strike'] == strike]['openInterest'].sum()
                put_oi = puts[puts['strike'] == strike]['openInterest'].sum()
                call_pain = call_oi * max(0, spot - strike) * 100
                put_pain = put_oi * max(0, strike - spot) * 100
                total_pain = call_pain + put_pain
                
                if total_pain < min_pain:
                    min_pain = total_pain
                    max_pain_strike = strike
            
            max_pain_data[ticker] = max_pain_strike
    except Exception as e:
        print(f"Fehler bei {ticker}: {e}")

with open('maxpain.json', 'w') as f:
    json.dump(max_pain_data, f, indent=2)
EOF

# GitHub Actions Ordner erstellen
mkdir -p .github/workflows

# maxpain.yml
cat > .github/workflows/maxpain.yml << 'EOF'
name: Update Max Pain Data

on:
  schedule:
    # Läuft Mo-Fr um 13:00 UTC (15:00 MESZ / 14:00 MEZ)
    - cron: '0 13 * * 1-5'
  workflow_dispatch:  # Ermöglicht manuelles Auslösen

jobs:
  update-maxpain:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout repository
      uses: actions/checkout@v3
      
    - name: Set up Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.9'
        
    - name: Install dependencies
      run: |
        pip install yfinance pandas
        
    - name: Run Max Pain calculation
      run: python maxpain.py
      
    - name: Commit and push if changed
      run: |
        git config --local user.email "action@github.com"
        git config --local user.name "GitHub Action"
        git add maxpain.json
        git diff --quiet && git diff --staged --quiet || (git commit -m "Update Max Pain data [skip ci]" && git push)
EOF

# README.md
cat > README.md << 'EOF'
# Options Dashboard

Ein minimalistisches Web-Dashboard zur Überwachung von Optionen mit Max Pain Berechnung.

## 🚀 Live Demo
[https://[IHR-USERNAME].github.io/options-dashboard/](https://[IHR-USERNAME].github.io/options-dashboard/)

## 📊 Features
- Echtzeit-Kurse von Yahoo Finance (15 Min. verzögert)
- TradingView Charts für jeden Ticker
- Max Pain Berechnung (täglich um 15:00 Uhr aktualisiert)
- Dark Theme
- Responsive Design
- Automatische Aktualisierung alle 60 Sekunden

## 🛠️ Technologie-Stack
- Vanilla JavaScript (ES Modules)
- GitHub Pages (Hosting)
- GitHub Actions (Automatisierung)
- TradingView Widgets
- Yahoo Finance API
- Python (yfinance) für Max Pain

## 💻 Lokale Entwicklung
```bash
# Repository klonen
git clone https://github.com/[IHR-USERNAME]/options-dashboard.git
cd options-dashboard

# Lokalen Server starten
python -m http.server 5500

# Dann öffnen: http://localhost:5500
```

## 📝 Ticker Liste
Die überwachten Ticker befinden sich in `tickers.json` und können dort angepasst werden.

## ⚙️ Max Pain Berechnung
Die Max Pain Werte werden automatisch montags bis freitags um 15:00 Uhr (deutscher Zeit) berechnet und in `maxpain.json` gespeichert. Die GitHub Action kann auch manuell ausgelöst werden.

## 📄 Lizenz
Dieses Projekt ist Open Source.
EOF

echo "✅ Alle Dateien wurden erstellt!"
echo ""
echo "📝 WICHTIG: Ersetzen Sie [IHR-USERNAME] in README.md mit Ihrem GitHub-Benutzernamen!"
echo ""
echo "Nächste Schritte:"
echo "1. Führen Sie 'chmod +x create-all-files.sh' aus (macht Script ausführbar)"
echo "2. Führen Sie './create-all-files.sh' aus"
echo "3. Committen Sie alle Dateien: git add . && git commit -m 'Initial setup' && git push"
echo "4. Aktivieren Sie GitHub Pages in den Repository-Settings"
echo "5. Setzen Sie die Workflow-Permissions auf 'Read and write'"
