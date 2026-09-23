# FPKG Mac Builder

FPKG Mac Builder è un’applicazione macOS Apple Silicon per creare pacchetti debug `.pkg` verificati da immagini e cartelle di giochi PS5.

Il motore è `fpkg-cli` con compressione BuiltIn Kraken livello 7. La versione attuale dell’interfaccia accetta cartelle di gioco e immagini `.ffpfsc` e `.exfat`. Il collegamento dell’interfaccia ai progetti `.gp5` e ai formati `.ffpkg` e `.ffpfs` è previsto per versioni successive. I contenitori `.ffpfsc` vengono letti in streaming tramite il supporto virtual-source.

## Stato

La build 1.0 è stata verificata su immagini reali di giochi PS5: icona, Content ID, Title ID, versione, modalità immagine e dimensione vengono letti correttamente. Il backend diretto è stato verificato con creazione e verifica completa del PKG a Kraken 7.

## Build locale

Il progetto richiede macOS 14 o successivo e Apple Silicon. La release include i runtime necessari e i testi di licenza dei componenti distribuiti.

La GUI è in [`mac-app/Main.swift`](mac-app/Main.swift), il coordinatore in [`mac-app/bridge.py`](mac-app/bridge.py) e il launcher del backend in [`mac-app/fpkg-direct-launcher`](mac-app/fpkg-direct-launcher).

## Licenze e distribuzione

`fpkg-cli` è un progetto separato di [rdmrocha/fpkg-cli](https://github.com/rdmrocha/fpkg-cli). La release distribuisce componenti precompilati insieme ai rispettivi avvisi: LibProsperoPkg è GPL-3.0-or-later, mentre il runtime .NET e gli altri componenti mantengono le proprie licenze e notice. Per redistribuire la `.app`, conserva questi file e rendi disponibile il sorgente corrispondente ai componenti GPL; i riferimenti ufficiali sono raccolti in [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md). Le build complete vengono pubblicate come asset GitHub Release.
