# FPKG Mac Converter

App macOS installata come `FPKG Mac Converter.app`.

Questa versione converte cartelle di gioco e immagini `.ffpfsc`, `.exfat`, `.ffpkg` e progetti `.gp5` quando riconosciuti dal backend incluso. Il supporto `.ffpfs` è previsto per una versione successiva. Il motore è `fpkg-cli nativo (Kraken 7)`, integrato dal progetto [rdmrocha/fpkg-cli](https://github.com/rdmrocha/fpkg-cli); gli originali non vengono modificati.

Prova documentata:

- 40/42 immagini del disco riconosciute dall’analisi automatica.
- Bendy and the Ink Machine riconosciuto, estratto e convertito.
- Pacchetto prodotto: `risultati/FPKG-d14rvwvj/EP5519-PPSA27616_00-0983640666583317-A0100-V0100.pkg`.
- Verifica finale completa: 10 controlli superati, inclusi checksum PFS, NAPS, file interni e CRC PlayGo.
- Gli altri due dump avevano un collision resolver obsoleto; l’app li legge comunque con avviso diagnostico.

Per usarla: apri FPKG Mac Converter, scegli una sorgente supportata, scegli una cartella di destinazione con spazio libero e premi **Crea e verifica PKG**. La versione 1.3.2 incorpora fpkg-cli, il runtime .NET 10 Apple Silicon, LibProsperoPkg e la patch di lettura `.ffpfsc`; non richiede installazioni separate di Python o .NET.

La destinazione deve avere spazio sufficiente per l’estrazione temporanea e il PKG finale. Per giochi molto grandi conviene usare un disco con almeno il doppio della dimensione del dump.
