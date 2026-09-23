import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    let source = NSTextField(string: "")
    let output = NSTextField(string: "")
    let titleLabel = NSTextField(labelWithString: "Scegli un gioco per iniziare")
    let detailLabel = NSTextField(wrappingLabelWithString: "Cartelle e contenitori FFPFSC con conversione nativa Kraken 7.")
    let gameIcon = NSImageView()
    let contentIDValue = NSTextField(labelWithString: "—")
    let titleIDValue = NSTextField(labelWithString: "—")
    let versionValue = NSTextField(labelWithString: "—")
    let packageTypeValue = NSTextField(labelWithString: "Applicazione / Gioco (APP)")
    let imageModeValue = NSTextField(labelWithString: "PLAINTEXT_NOAUTH")
    let sourceFormatValue = NSTextField(labelWithString: "—")
    let status = NSTextField(labelWithString: "Pronto")
    let progress = NSProgressIndicator()
    let log = NSTextView()
    let engine = NSPopUpButton()
    var buildButton: NSButton!
    var cancelButton: NSButton!
    var showButton: NSButton!
    var controls: [NSControl] = []
    var process: Process?
    var resultURL: URL?
    var buffer = Data()
    var gotError = false
    var inspectedSource: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.appearance = NSAppearance(named: .darkAqua)
        let menu = NSMenu()
        let appItem = NSMenuItem(); menu.addItem(appItem)
        let appMenu = NSMenu(); appItem.submenu = appMenu
        appMenu.addItem(withTitle: "Esci da FPKG Mac", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let editItem = NSMenuItem(); menu.addItem(editItem)
        let edit = NSMenu(title: "Modifica"); editItem.submenu = edit
        edit.addItem(withTitle: "Copia", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Incolla", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Seleziona tutto", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        NSApp.mainMenu = menu
        window = NSWindow(contentRect: NSRect(x:0,y:0,width:1040,height:860), styleMask:[.titled,.closable,.miniaturizable,.resizable], backing:.buffered, defer:false)
        window.title = "FPKG Mac — PFS annidati"
        window.minSize = NSSize(width:900,height:760)
        window.delegate = self
        let root = NSStackView(); root.orientation = .vertical; root.alignment = .leading; root.spacing = 14
        root.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(root)
        NSLayoutConstraint.activate([root.leadingAnchor.constraint(equalTo:window.contentView!.leadingAnchor,constant:26),root.trailingAnchor.constraint(equalTo:window.contentView!.trailingAnchor,constant:-26),root.topAnchor.constraint(equalTo:window.contentView!.topAnchor,constant:24),root.bottomAnchor.constraint(equalTo:window.contentView!.bottomAnchor,constant:-24)])
        let heading = NSTextField(labelWithString:"FPKG Mac")
        heading.font = .systemFont(ofSize:30,weight:.bold)
        root.addArrangedSubview(heading)
        let subtitle = NSTextField(labelWithString:"I tuoi giochi, leggibili anche su Mac.")
        subtitle.textColor = .secondaryLabelColor; root.addArrangedSubview(subtitle)
        root.addArrangedSubview(NSTextField(labelWithString:"1   SORGENTE"))
        source.placeholderString="Seleziona il file .ffpfsc oppure la cartella del gioco";source.isEditable=false
        let file = button("Scegli file…",#selector(pickFile)); let folder=button("Cartella…",#selector(pickFolder))
        addRow(root,[source,file,folder]);controls += [file,folder]
        let detailsCard=packageDetailsCard();root.addArrangedSubview(detailsCard)
        detailsCard.widthAnchor.constraint(equalTo:root.widthAnchor).isActive=true
        root.addArrangedSubview(NSTextField(labelWithString:"2   DESTINAZIONE DEL PACCHETTO"))
        output.placeholderString="Scegli un disco con spazio per estrazione e pacchetto";output.isEditable=false
        let dest=button("Scegli…",#selector(pickOutput));addRow(root,[output,dest]);controls.append(dest)
        engine.addItem(withTitle:"fpkg-cli nativo (Kraken 7)")
        engine.selectItem(at:0)
        engine.isEnabled = false
        let label=NSTextField(labelWithString:"Motore:");addRow(root,[label,engine]);controls.append(engine)
        let note=NSTextField(wrappingLabelWithString:"L’originale viene letto senza modificarlo. Ogni conversione crea una cartella separata; i file temporanei vengono rimossi al termine. Il pacchetto finale viene verificato.")
        note.font = .systemFont(ofSize:12);note.textColor = .secondaryLabelColor;root.addArrangedSubview(note)
        buildButton=button("Crea e verifica PKG",#selector(build));buildButton.bezelStyle = .rounded;buildButton.contentTintColor = .systemGreen;buildButton.isEnabled=false
        cancelButton=button("Annulla",#selector(cancel));cancelButton.isEnabled=false
        showButton=button("Mostra risultato",#selector(showResult));showButton.isEnabled=false
        addRow(root,[buildButton,cancelButton,showButton])
        progress.minValue=0;progress.maxValue=1;progress.isIndeterminate=false;progress.style = .bar
        root.addArrangedSubview(progress);progress.widthAnchor.constraint(equalTo:root.widthAnchor).isActive=true
        root.addArrangedSubview(status)
        let scroll=NSScrollView();scroll.hasVerticalScroller=true;scroll.borderType = .bezelBorder
        log.isEditable=false;log.isSelectable=true;log.font = .monospacedSystemFont(ofSize:11,weight:.regular)
        log.autoresizingMask=[.width];log.textContainer?.widthTracksTextView=true
        scroll.documentView=log;root.addArrangedSubview(scroll)
        scroll.widthAnchor.constraint(equalTo:root.widthAnchor).isActive=true
        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant:150).isActive=true
        let credits=NSTextField(labelWithString:"Lettura e pacchetti: fpkg-cli · LibProsperoPkg · Kraken 7 · FPKG Mac 1.3")
        credits.font = .systemFont(ofSize:10);credits.textColor = .tertiaryLabelColor;root.addArrangedSubview(credits)
        window.center();window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
    }
    func button(_ text:String,_ action:Selector)->NSButton { let b=NSButton(title:text,target:self,action:action);b.bezelStyle = .rounded;return b }
    func packageDetailsCard()->NSView {
        let box=NSBox();box.boxType = .custom;box.cornerRadius=12;box.borderWidth=1
        box.borderColor=NSColor.separatorColor;box.fillColor=NSColor.controlBackgroundColor
        let card=NSStackView();card.orientation = .horizontal;card.alignment = .top;card.spacing=20
        card.translatesAutoresizingMaskIntoConstraints=false
        let content=NSView();content.addSubview(card);box.contentView=content
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo:content.leadingAnchor,constant:16),
            card.trailingAnchor.constraint(equalTo:content.trailingAnchor,constant:-16),
            card.topAnchor.constraint(equalTo:content.topAnchor,constant:16),
            card.bottomAnchor.constraint(equalTo:content.bottomAnchor,constant:-16)
        ])

        gameIcon.image=NSImage(named:NSImage.applicationIconName);gameIcon.imageScaling = .scaleProportionallyUpOrDown
        gameIcon.wantsLayer=true;gameIcon.layer?.cornerRadius=16;gameIcon.layer?.masksToBounds=true
        gameIcon.layer?.backgroundColor=NSColor.windowBackgroundColor.cgColor
        gameIcon.widthAnchor.constraint(equalToConstant:148).isActive=true
        gameIcon.heightAnchor.constraint(equalToConstant:148).isActive=true
        card.addArrangedSubview(gameIcon)

        let info=NSStackView();info.orientation = .vertical;info.alignment = .leading;info.spacing=8
        titleLabel.font = .systemFont(ofSize:22,weight:.semibold);titleLabel.maximumNumberOfLines=2
        detailLabel.textColor = .secondaryLabelColor;detailLabel.font = .systemFont(ofSize:12)
        info.addArrangedSubview(titleLabel);info.addArrangedSubview(detailLabel)

        let grid=NSGridView(views:[
            [fieldName("CONTENT ID"),contentIDValue,fieldName("TITLE ID"),titleIDValue],
            [fieldName("VERSIONE"),versionValue,fieldName("TIPO PACCHETTO"),packageTypeValue],
            [fieldName("IMAGE MODE"),imageModeValue,fieldName("FORMATO SORGENTE"),sourceFormatValue]
        ])
        grid.rowSpacing=7;grid.columnSpacing=12;grid.xPlacement = .leading;grid.yPlacement = .center
        for value in [contentIDValue,titleIDValue,versionValue,packageTypeValue,imageModeValue,sourceFormatValue] {
            value.font = .monospacedSystemFont(ofSize:11,weight:.medium)
            value.textColor = .labelColor
            value.lineBreakMode = .byTruncatingMiddle
        }
        info.addArrangedSubview(grid);card.addArrangedSubview(info)
        info.setContentHuggingPriority(.defaultLow,for:.horizontal)
        box.heightAnchor.constraint(greaterThanOrEqualToConstant:180).isActive=true
        return box
    }
    func fieldName(_ text:String)->NSTextField {
        let label=NSTextField(labelWithString:text);label.font = .systemFont(ofSize:10,weight:.semibold)
        label.textColor = .secondaryLabelColor;return label
    }
    func addRow(_ root:NSStackView,_ views:[NSView]) {
        let row=NSStackView(views:views);row.orientation = .horizontal;row.spacing=10
        root.addArrangedSubview(row);row.widthAnchor.constraint(equalTo:root.widthAnchor).isActive=true
        for v in views where v is NSTextField { v.setContentHuggingPriority(.defaultLow,for:.horizontal) }
    }
    @objc func pickFile(){ pickSource(directory:false) }
    @objc func pickFolder(){ pickSource(directory:true) }
    func pickSource(directory:Bool) {
        let panel=NSOpenPanel();panel.canChooseDirectories=directory;panel.canChooseFiles = !directory;panel.allowsMultipleSelection=false
        panel.beginSheetModal(for:window){ response in
            guard response == .OK, let url=panel.url else{return}
            self.source.stringValue=url.path;self.inspectedSource=nil;self.resultURL=nil;self.showButton.isEnabled=false
            self.titleLabel.stringValue="Lettura del gioco…"
            self.detailLabel.stringValue="Analisi dei metadati e dell’icona in corso…"
            self.gameIcon.image=NSImage(named:NSImage.applicationIconName)
            self.start(["inspect",url.path],building:false)
        }
    }
    @objc func pickOutput(){
        let panel=NSOpenPanel();panel.canChooseDirectories=true;panel.canChooseFiles=false;panel.canCreateDirectories=true
        panel.beginSheetModal(for:window){ response in
            if response == .OK,let url=panel.url {self.output.stringValue=url.path;self.updateBuild()}
        }
    }
    func updateBuild(){buildButton.isEnabled=process == nil && inspectedSource == source.stringValue && !output.stringValue.isEmpty}
    @objc func build(){
        resultURL=nil;showButton.isEnabled=false
        start(["build",source.stringValue,output.stringValue,"direct"],building:true)
    }
    func append(_ text:String){
        log.textStorage?.append(NSAttributedString(string:text+"\n",attributes:[.foregroundColor:NSColor.textColor]))
        if log.string.count>150000 {log.textStorage?.deleteCharacters(in:NSRange(location:0,length:30000))}
        log.scrollToEndOfDocument(nil)
    }
    func handle(_ data:Data){
        guard let event=(try? JSONSerialization.jsonObject(with:data)) as? [String:Any],let kind=event["event"] as? String else{if let text=String(data:data,encoding:.utf8){append(text)};return}
        switch kind {
        case "metadata":
            titleLabel.stringValue=event["title"] as? String ?? "Gioco"
            let size=(event["bytes"] as? Double ?? 0)/1e9
            detailLabel.stringValue="\(event["files"] as? Int ?? 0) file   ·   \(String(format:"%.2f",size)) GB   ·   sorgente letta senza modifiche"
            contentIDValue.stringValue=event["content_id"] as? String ?? "—"
            titleIDValue.stringValue=event["title_id"] as? String ?? "—"
            versionValue.stringValue=event["version"] as? String ?? "—"
            packageTypeValue.stringValue=event["package_type"] as? String ?? "Applicazione / Gioco (APP)"
            imageModeValue.stringValue=event["image_mode"] as? String ?? "PLAINTEXT_NOAUTH"
            sourceFormatValue.stringValue=event["format"] as? String ?? "—"
            if let encoded=event["icon_b64"] as? String,let data=Data(base64Encoded:encoded),let image=NSImage(data:data) {
                gameIcon.image=image
            }
            inspectedSource=source.stringValue
        case "progress":
            progress.doubleValue=event["value"] as? Double ?? 0
            status.stringValue="\(event["text"] as? String ?? "") — \(event["detail"] as? String ?? "")"
        case "done":
            progress.doubleValue=1;status.stringValue="Pacchetto creato e verificato"
            if let path=event["path"] as? String {resultURL=URL(fileURLWithPath:path);append(path);showButton.isEnabled=true}
        case "error":gotError=true;status.stringValue="Operazione non completata";append(event["text"] as? String ?? "Errore")
        default:if let text=event["text"] as? String{append(text)}
    }
    }
    func start(_ args:[String],building:Bool){
        guard process == nil else{return}
        guard let resources=Bundle.main.resourceURL else{return}
        gotError=false;buffer=Data();log.string="";progress.doubleValue=0
        status.stringValue=building ? "Preparazione della conversione…":"Analisi della sorgente…"
        let runtime=resources.appendingPathComponent("runtime.json")
        guard let data=try? Data(contentsOf:runtime),let config=(try? JSONSerialization.jsonObject(with:data)) as? [String:String],let python=config["python"] else{append("Configurazione Python mancante");return}
        let pythonURL = python.hasPrefix("/") ? URL(fileURLWithPath:python) : resources.appendingPathComponent(python)
        let p=Process();p.executableURL=pythonURL
        var environment = ProcessInfo.processInfo.environment
        environment["PYTHONDONTWRITEBYTECODE"] = "1"
        environment["PYTHONNOUSERSITE"] = "1"
        p.environment=environment
        p.arguments=["-u",resources.appendingPathComponent("bridge.py").path]+args
        let pipe=Pipe();p.standardOutput=pipe;p.standardError=pipe
        pipe.fileHandleForReading.readabilityHandler={ handle in
            let bytes=handle.availableData
            if bytes.isEmpty {handle.readabilityHandler=nil;return}
            DispatchQueue.main.async{
                self.buffer.append(bytes)
                while let end=self.buffer.firstIndex(of:10){
                    let line=self.buffer.prefix(upTo:end);self.buffer.removeSubrange(...end)
                    self.handle(Data(line))
                }
            }
        }
        p.terminationHandler={ proc in DispatchQueue.main.async{
            self.process=nil;for c in self.controls{c.isEnabled=true};self.cancelButton.isEnabled=false
            if proc.terminationStatus != 0{self.gotError=true;self.status.stringValue="Operazione non completata — consulta il log"}
            else if !building && !self.gotError{self.status.stringValue="Sorgente riconosciuta. Scegli la destinazione e crea il pacchetto."}
            self.updateBuild()
        }}
        do{try p.run();process=p;for c in controls{c.isEnabled=false};buildButton.isEnabled=false;cancelButton.isEnabled=true}
        catch{append("Impossibile avviare il motore: \(error.localizedDescription)");status.stringValue="Avvio fallito"}
    }
    @objc func cancel(){status.stringValue="Annullamento e pulizia dei temporanei…";cancelButton.isEnabled=false;process?.terminate()}
    @objc func showResult(){if let url=resultURL{NSWorkspace.shared.activateFileViewerSelecting([url])}}
    func applicationShouldTerminate(_ sender:NSApplication)->NSApplication.TerminateReply {
        if process != nil {let alert=NSAlert();alert.messageText="Operazione in corso";alert.informativeText="Premi Annulla e attendi la pulizia prima di chiudere.";alert.runModal();return .terminateCancel}
        return .terminateNow
    }
    func windowShouldClose(_ sender:NSWindow)->Bool {if process != nil{return false};NSApp.terminate(nil);return true}
}
let app=NSApplication.shared
let delegate=AppDelegate()
app.delegate=delegate
app.run()
