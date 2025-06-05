#!/usr/bin/env python3
"""
Minimal-robustes Max-Pain-Skript für GitHub Actions
– liest tickers.json (Array aus Strings)
– nimmt stets das nächstliegende Verfallsdatum
– speichert Ergebnisse + 24-h-Cache in maxpain.json
"""
import json, time, pathlib, datetime as dt
import yfinance as yf
from typing import Dict, List, Optional

# ---------------- Einstellungen ---------------- #
TICKER_FILE      = "tickers.json"
OUTPUT_FILE      = "maxpain.json"
CACHE_FILE       = "maxpain_cache.json"
CACHE_HOURS      = 24            # Yahoo-OI verändert sich nur über Nacht
MIN_OPEN_INTEREST = 10           # alles darunter ignorieren
# ------------------------------------------------ #

def load_tickers(path: str) -> List[str]:
    return json.loads(pathlib.Path(path).read_text())

def cache_valid(entry: Dict) -> bool:
    try:
        ts = dt.datetime.fromisoformat(entry["ts"])
        return dt.datetime.now() - ts < dt.timedelta(hours=CACHE_HOURS)
    except Exception:
        return False

def calc_max_pain(symbol: str) -> Optional[float]:
    tk = yf.Ticker(symbol)
    if not tk.options:
        return None
    expiry = tk.options[0]
    chain  = tk.option_chain(expiry)
    calls, puts = chain.calls, chain.puts

    # Filter Open Interest
    calls = calls[calls.openInterest >= MIN_OPEN_INTEREST]
    puts  = puts[puts.openInterest  >= MIN_OPEN_INTEREST]

    if calls.empty and puts.empty:
        return None

    strikes = sorted(set(calls.strike.tolist() + puts.strike.tolist()))
    best_strike, best_pain = None, float("inf")

    for strike in strikes:
        pain_calls = ((strike - calls[calls.strike < strike].strike) *
                      calls[calls.strike < strike].openInterest).sum()
        pain_puts  = ((puts[puts.strike > strike].strike - strike) *
                      puts[puts.strike > strike].openInterest).sum()
        total_pain = pain_calls + pain_puts
        if total_pain < best_pain:
            best_pain, best_strike = total_pain, strike
    return float(best_strike) if best_strike is not None else None

def main():
    tickers = load_tickers(TICKER_FILE)
    cache   = {}
    if pathlib.Path(CACHE_FILE).exists():
        cache = json.loads(pathlib.Path(CACHE_FILE).read_text())

       results = {}
    for raw in tickers:
        # akzeptiert "AAPL"  **oder**  {"symbol":"AAPL", "enabled":true}
        if isinstance(raw, dict):
            if not raw.get("enabled", True):
                print(f"{raw.get('symbol')} übersprungen (disabled)")
                continue
            symbol = raw.get("symbol")
        else:
            symbol = raw

        if not symbol:
            continue

        # Cache-Check
        if symbol in cache and cache_valid(cache[symbol]):
            results[symbol] = cache[symbol]["mp"]
            print(f"{symbol}: aus Cache → {results[symbol]}")
            continue

        print(f"{symbol}: berechne …", end="")
        mp = calc_max_pain(symbol)
        if mp:
            print(f"  MaxPain {mp}")
            results[symbol] = mp
            cache[symbol] = {"mp": mp, "ts": dt.datetime.now().isoformat()}
        else:
            print("  keine Daten")

        time.sleep(1)   # freundliche Pause

    # Dateien schreiben
    pathlib.Path(OUTPUT_FILE).write_text(json.dumps(results, indent=2))
    pathlib.Path(CACHE_FILE).write_text(json.dumps(cache, indent=2))
    print(f"\nFertig – {len(results)} Werte in {OUTPUT_FILE}")

if __name__ == "__main__":
    main()
