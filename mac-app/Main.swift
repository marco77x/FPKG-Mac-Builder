import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    let source = NSTextField(string: "")
    let output = NSTextField(string: "")
    let titleLabel = NSTextField(labelWithString: "Choose a game to begin")
    let detailLabel = NSTextField(wrappingLabelWithString: "Game folders and FFPFSC containers with native Kraken 7 conversion.")
    let gameIcon = NSImageView()
    let contentIDValue = NSTextField(labelWithString: "—")
    let titleIDValue = NSTextField(labelWithString: "—")
    let versionValue = NSTextField(labelWithString: "—")
    let packageTypeValue = NSTextField(labelWithString: "Application / Game (APP)")
    let imageModeValue = NSTextField(labelWithString: "PLAINTEXT_NOAUTH")
    let sourceFormatValue = NSTextField(labelWithString: "—")
    let status = NSTextField(labelWithString: "Ready")
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
        appMenu.addItem(withTitle: "Quit FPKG Mac Builder", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let editItem = NSMenuItem(); menu.addItem(editItem)
        let edit = NSMenu(title: "Edit"); editItem.submenu = edit
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        NSApp.mainMenu = menu
        window = NSWindow(contentRect: NSRect(x:0,y:0,width:1040,height:860), styleMask:[.titled,.closable,.miniaturizable,.resizable], backing:.buffered, defer:false)
        window.title = "FPKG Mac Builder"
        window.minSize = NSSize(width:900,height:760)
        window.delegate = self
        let root = NSStackView(); root.orientation = .vertical; root.alignment = .leading; root.spacing = 14
        root.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(root)
        NSLayoutConstraint.activate([root.leadingAnchor.constraint(equalTo:window.contentView!.leadingAnchor,constant:26),root.trailingAnchor.constraint(equalTo:window.contentView!.trailingAnchor,constant:-26),root.topAnchor.constraint(equalTo:window.contentView!.topAnchor,constant:24),root.bottomAnchor.constraint(equalTo:window.contentView!.bottomAnchor,constant:-24)])
        let heading = NSTextField(labelWithString:"FPKG Mac Builder")
        heading.font = .systemFont(ofSize:30,weight:.bold)
        root.addArrangedSubview(heading)
        let subtitle = NSTextField(labelWithString:"Convert PS5 game images and folders into verified FPKG packages.")
        subtitle.textColor = .secondaryLabelColor; root.addArrangedSubview(subtitle)
        root.addArrangedSubview(NSTextField(labelWithString:"1   SOURCE"))
        source.placeholderString="Select an .ffpfsc file or game folder";source.isEditable=false
        let file = button("Choose File…",#selector(pickFile)); let folder=button("Folder…",#selector(pickFolder))
        addRow(root,[source,file,folder]);controls += [file,folder]
        let detailsCard=packageDetailsCard();root.addArrangedSubview(detailsCard)
        detailsCard.widthAnchor.constraint(equalTo:root.widthAnchor).isActive=true
        root.addArrangedSubview(NSTextField(labelWithString:"2   PACKAGE DESTINATION"))
        output.placeholderString="Choose a disk with space for extraction and the package";output.isEditable=false
        let dest=button("Choose…",#selector(pickOutput));addRow(root,[output,dest]);controls.append(dest)
        engine.addItem(withTitle:"Native fpkg-cli (Kraken 7)")
        engine.selectItem(at:0)
        engine.isEnabled = false
        let label=NSTextField(labelWithString:"Engine:");addRow(root,[label,engine]);controls.append(engine)
        let note=NSTextField(wrappingLabelWithString:"The original source is read without modification. Each conversion uses a separate folder; temporary files are removed when it finishes. The final package is verified.")
        note.font = .systemFont(ofSize:12);note.textColor = .secondaryLabelColor;root.addArrangedSubview(note)
        buildButton=button("Create and Verify PKG",#selector(build));buildButton.bezelStyle = .rounded;buildButton.contentTintColor = .systemGreen;buildButton.isEnabled=false
        cancelButton=button("Cancel",#selector(cancel));cancelButton.isEnabled=false
        showButton=button("Show Result",#selector(showResult));showButton.isEnabled=false
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
        let credits=NSTextField(labelWithString:"FPKG Mac Builder · fpkg-cli · LibProsperoPkg · Kraken 7 · version 1.0")
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
            [fieldName("VERSION"),versionValue,fieldName("PACKAGE TYPE"),packageTypeValue],
            [fieldName("IMAGE MODE"),imageModeValue,fieldName("SOURCE FORMAT"),sourceFormatValue]
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
            self.titleLabel.stringValue="Reading game…"
            self.detailLabel.stringValue="Reading metadata and icon…"
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
            titleLabel.stringValue=event["title"] as? String ?? "Game"
            let size=(event["bytes"] as? Double ?? 0)/1e9
            detailLabel.stringValue="\(event["files"] as? Int ?? 0) file   ·   \(String(format:"%.2f",size)) GB   ·   source read without modification"
            contentIDValue.stringValue=event["content_id"] as? String ?? "—"
            titleIDValue.stringValue=event["title_id"] as? String ?? "—"
            versionValue.stringValue=event["version"] as? String ?? "—"
            packageTypeValue.stringValue=event["package_type"] as? String ?? "Application / Game (APP)"
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
            progress.doubleValue=1;status.stringValue="Package created and verified"
            if let path=event["path"] as? String {resultURL=URL(fileURLWithPath:path);append(path);showButton.isEnabled=true}
        case "error":gotError=true;status.stringValue="Operation failed";append(event["text"] as? String ?? "Error")
        default:if let text=event["text"] as? String{append(text)}
    }
    }
    func start(_ args:[String],building:Bool){
        guard process == nil else{return}
        guard let resources=Bundle.main.resourceURL else{return}
        gotError=false;buffer=Data();log.string="";progress.doubleValue=0
        status.stringValue=building ? "Preparing conversion…":"Analyzing source…"
        let runtime=resources.appendingPathComponent("runtime.json")
        guard let data=try? Data(contentsOf:runtime),let config=(try? JSONSerialization.jsonObject(with:data)) as? [String:String],let python=config["python"] else{append("Missing Python configuration");return}
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
            if proc.terminationStatus != 0{self.gotError=true;self.status.stringValue="Operation failed — consulta il log"}
            else if !building && !self.gotError{self.status.stringValue="Source recognized. Choose a destination and create the package."}
            self.updateBuild()
        }}
        do{try p.run();process=p;for c in controls{c.isEnabled=false};buildButton.isEnabled=false;cancelButton.isEnabled=true}
        catch{append("Unable to start the engine: \(error.localizedDescription)");status.stringValue="Startup failed"}
    }
    @objc func cancel(){status.stringValue="Cancelmento e pulizia dei temporanei…";cancelButton.isEnabled=false;process?.terminate()}
    @objc func showResult(){if let url=resultURL{NSWorkspace.shared.activateFileViewerSelecting([url])}}
    func applicationShouldTerminate(_ sender:NSApplication)->NSApplication.TerminateReply {
        if process != nil {let alert=NSAlert();alert.messageText="Operation in progress";alert.informativeText="Premi Cancel e attendi la pulizia prima di chiudere.";alert.runModal();return .terminateCancel}
        return .terminateNow
    }
    func windowShouldClose(_ sender:NSWindow)->Bool {if process != nil{return false};NSApp.terminate(nil);return true}
}
let app=NSApplication.shared
let delegate=AppDelegate()
app.delegate=delegate
app.run()
