import json
import yfinance as yf
from datetime import datetime

def calculate_max_pain(symbol):
    try:
        stock = yf.Ticker(symbol)
        
        # Hole alle verfügbaren Optionen-Verfallsdaten
        exp_dates = stock.options
        
        if not exp_dates:
            return None
            
        # Nimm das nächste Verfallsdatum
        next_expiry = exp_dates[0]
        
        # Hole Options-Chain
        opt_chain = stock.option_chain(next_expiry)
        calls = opt_chain.calls
        puts = opt_chain.puts
        
        # Berechne Max Pain
        strikes = sorted(set(calls['strike'].tolist() + puts['strike'].tolist()))
        
        max_pain_value = 0
        max_pain_strike = 0
        
        for strike in strikes:
            call_pain = 0
            put_pain = 0
            
            # Berechne Call Pain
            call_otm = calls[calls['strike'] < strike]
            if not call_otm.empty:
                call_pain = sum(call_otm['openInterest'] * (strike - call_otm['strike']))
            
            # Berechne Put Pain
            put_otm = puts[puts['strike'] > strike]
            if not put_otm.empty:
                put_pain = sum(put_otm['openInterest'] * (put_otm['strike'] - strike))
            
            total_pain = call_pain + put_pain
            
            if max_pain_value == 0 or total_pain < max_pain_value:
                max_pain_value = total_pain
                max_pain_strike = strike
        
        return {
            'maxPain': max_pain_strike,
            'expiryDate': next_expiry,
            'lastUpdate': datetime.now().isoformat()
        }
        
    except Exception as e:
        print(f"Fehler bei {symbol}: {str(e)}")
        return None

def main():
    # Lade Ticker-Liste
    with open('tickers.json', 'r') as f:
        tickers = json.load(f)
    
    max_pain_data = {}
    
    # Berechne Max Pain für jeden Ticker
    for ticker in tickers:
        symbol = ticker['symbol']
        print(f"Berechne Max Pain für {symbol}...")
        result = calculate_max_pain(symbol)
        if result:
            max_pain_data[symbol] = result
    
    # Speichere Ergebnisse
    with open('maxpain_data.json', 'w') as f:
        json.dump(max_pain_data, f, indent=2)
    
    print("Max Pain Berechnung abgeschlossen!")

if __name__ == "__main__":
    main()
