# FPKG Mac Converter

FPKG Mac è un’applicazione macOS Apple Silicon per leggere immagini PS5 `.ffpfsc`, mostrare i metadati del gioco e creare pacchetti debug `.pkg` verificati.

Il motore è `fpkg-cli` con compressione BuiltIn Kraken livello 7. La lettura dei contenitori `.ffpfsc` avviene in streaming tramite il supporto virtual-source.

## Stato

La build installata è la 1.2. È stata verificata su un’immagine reale di un gioco PS5: icona, Content ID, Title ID, versione, modalità immagine e dimensione vengono letti correttamente. Il backend diretto è stato verificato su un contenitore sintetico con creazione e verifica completa del PKG a Kraken 7.

## Build locale

Il progetto richiede macOS 14 o successivo, Apple Silicon, Xcode Command Line Tools e Python 3.14. LibProsperoPkg e i binari di terze parti non sono inclusi nel repository: devono essere ottenuti nel rispetto delle rispettive licenze.

La GUI è in [`mac-app/Main.swift`](mac-app/Main.swift), il coordinatore in [`mac-app/bridge.py`](mac-app/bridge.py) e il launcher del backend in [`mac-app/fpkg-direct-launcher`](mac-app/fpkg-direct-launcher).

## Licenze e distribuzione

`fpkg-cli` è un progetto separato di [rdmrocha/fpkg-cli](https://github.com/rdmrocha/fpkg-cli). Prima di pubblicare una `.app` completa, verificare i termini di distribuzione di LibProsperoPkg, .NET e degli altri componenti inclusi. Le build `.app` complete sono adatte a una GitHub Release come asset, non a un commit Git.
