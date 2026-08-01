import AppKit
import CryptoKit
import Foundation
import Network

func log(_ msg: String) {
    FileHandle.standardError.write(Data("\(msg)\n".utf8))
}

// MARK: - Data Models

struct AppInfo: Codable {
    let name: String
    let bundleId: String
    let pid: Int32
}

enum WSMessageType: String, Codable {
    case appList
    case focus
}

struct WSMessage: Codable {
    let type: WSMessageType
    let apps: [AppInfo]?
    let bundleId: String?
}

let serviceType = "_appswitcher._tcp."
let port: UInt16 = 8080

func getRunningApps() -> [AppInfo] {
    NSWorkspace.shared.runningApplications
        .filter { $0.activationPolicy == .regular }
        .compactMap { app in
            guard let name = app.localizedName,
                  let bundleId = app.bundleIdentifier else { return nil }
            return AppInfo(name: name, bundleId: bundleId, pid: app.processIdentifier)
        }
}

func focusApp(bundleId: String) {
    let apps = NSWorkspace.shared.runningApplications
    guard let app = apps.first(where: { $0.bundleIdentifier == bundleId }),
          let name = app.localizedName else {
        log("[server] App not running: \(bundleId)")
        return
    }
    let task = Process()
    task.launchPath = "/usr/bin/osascript"
    task.arguments = ["-e", "tell application \"\(name)\" to activate"]
    task.standardOutput = FileHandle.nullDevice
    task.standardError = FileHandle.nullDevice
    task.launch()
    log("[server] Focused: \(name)")
}

// MARK: - WebSocket (RFC 6455) helpers

func wsAccept(key: String) -> String {
    let k = (key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").data(using: .utf8)!
    return Data(Insecure.SHA1.hash(data: k)).base64EncodedString()
}

func wsFrame(_ text: String) -> Data {
    var data = Data([0x81])
    let bytes = text.data(using: .utf8)!
    let len = bytes.count
    switch len {
    case 0..<126: data.append(UInt8(len))
    case 0..<65536: data.append(contentsOf: [126, UInt8(len >> 8), UInt8(len & 0xff)])
    default: data.append(127); for i in stride(from: 7, through: 0, by: -1) { data.append(UInt8((len >> (i*8)) & 0xff)) }
    }
    data.append(bytes)
    return data
}

func wsDecode(_ data: Data) -> String? {
    let b = [UInt8](data)
    guard b.count >= 2, (b[0] & 0x0f) == 1 else { return nil }
    let masked = (b[1] & 0x80) != 0
    var len = Int(b[1] & 0x7f), off = 2
    if len == 126 { len = (Int(b[2]) << 8) | Int(b[3]); off = 4 }
    else if len == 127 { len = 0; for i in 2..<10 { len = (len << 8) | Int(b[i]) }; off = 10 }
    var mask: [UInt8] = []
    if masked { mask = Array(b[off..<off+4]); off += 4 }
    guard off + len <= b.count else { return nil }
    if masked {
        var r = [UInt8]()
        for i in 0..<len { r.append(b[off + i] ^ mask[i % 4]) }
        return String(bytes: r, encoding: .utf8)
    }
    return String(bytes: b[off..<off+len], encoding: .utf8)
}

// MARK: - Server

final class Server {
    private var listener: NWListener?
    private var connections: [(conn: NWConnection, ws: Bool)] = []
    private var broadcastTimer: Timer?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func start() throws {
        let tcpOpts = NWProtocolTCP.Options()
        listener = try NWListener(using: NWParameters(tls: nil, tcp: tcpOpts), on: NWEndpoint.Port(rawValue: port)!)
        listener?.newConnectionHandler = { [weak self] conn in self?.handleConnection(conn) }
        listener?.stateUpdateHandler = { s in log("[server] State: \(s)") }
        listener?.start(queue: .main)
        broadcastTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.broadcastApps() }
        log("[server] Running on port \(port)")
    }

    func stop() {
        broadcastTimer?.invalidate()
        connections.forEach { $0.conn.cancel() }
        connections.removeAll()
        listener?.cancel()
    }

    private func handleConnection(_ conn: NWConnection) {
        connections.append((conn, false))
        conn.start(queue: .main)
        conn.receive(minimumIncompleteLength: 1, maximumLength: 16384) { [weak self] data, _, isComplete, error in
            guard let self, let data = data, error == nil else { self?.remove(conn); return }
            let str = String(data: data, encoding: .utf8) ?? ""
            if str.lowercased().contains("upgrade:") && str.lowercased().contains("websocket") {
                self.upgradeWS(on: conn, headers: str)
            } else if str.hasPrefix("GET ") {
                let parts = str.components(separatedBy: " ")
                let path = parts.count > 1 ? parts[1] : "/"
                if path.hasPrefix("/icon?") {
                    self.serveIcon(on: conn, path: path)
                } else {
                    self.serveHTML(on: conn)
                }
            } else {
                self.remove(conn)
            }
        }
    }

    private func serveIcon(on conn: NWConnection, path: String) {
        var bundleId = ""
        for p in path.components(separatedBy: "?")[1...].joined(separator: "?").components(separatedBy: "&") {
            let kv = p.components(separatedBy: "=")
            if kv.count == 2 && kv[0] == "bundleId" { bundleId = kv[1].removingPercentEncoding ?? "" }
        }

        var icon: NSImage?
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleId }) {
            icon = app.icon
        }
        if icon == nil, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            icon = NSWorkspace.shared.icon(forFile: url.path)
        }

        var pngData = Data()
        if let icon = icon {
            let size = NSSize(width: 240, height: 240)
            let resized = NSImage(size: size)
            resized.lockFocus()
            icon.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1.0)
            resized.unlockFocus()
            if let tiff = resized.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiff),
               let png = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.6]) {
                pngData = png
            }
        }
        let res = "HTTP/1.1 200 OK\r\nContent-Type: image/jpeg\r\nContent-Length: \(pngData.count)\r\nCache-Control: max-age=300\r\nConnection: close\r\n\r\n"
        conn.send(content: res.data(using: .utf8)! + pngData, completion: .contentProcessed { _ in conn.cancel() })
    }

    private func serveHTML(on conn: NWConnection) {
        let html = webAppHTML()
        let res = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(html.utf8.count)\r\nConnection: close\r\n\r\n\(html)"
        conn.send(content: res.data(using: .utf8)!, completion: .contentProcessed { _ in conn.cancel() })
    }

    private func upgradeWS(on conn: NWConnection, headers: String) {
        var key = ""
        for line in headers.components(separatedBy: "\r\n") {
            if line.lowercased().hasPrefix("sec-websocket-key:") {
                key = line.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
            }
        }
        let res = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: \(wsAccept(key: key))\r\n\r\n"
        conn.send(content: res.data(using: .utf8)!, completion: .contentProcessed { [weak self] _ in
            self?.onWSConnected(conn)
        })
    }

    private func onWSConnected(_ conn: NWConnection) {
        if let i = connections.firstIndex(where: { $0.conn === conn }) { connections[i] = (conn, true) }
        log("[server] Client connected (\(self.wsCount) total)")
        sendAppList(to: conn)
        readWS(on: conn)
    }

    private var wsCount: Int { connections.filter(\.ws).count }

    private func readWS(on conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data = data, let text = wsDecode(data),
               let msg = try? self.decoder.decode(WSMessage.self, from: text.data(using: .utf8)!) {
                if msg.type == .focus, let bundleId = msg.bundleId { focusApp(bundleId: bundleId) }
            }
            if error != nil || isComplete {
                self.connections.removeAll { $0.conn === conn }
                log("[server] Client disconnected (\(self.wsCount) remaining)")
                return
            }
            self.readWS(on: conn)
        }
    }

    private func sendAppList(to conn: NWConnection) {
        let msg = WSMessage(type: .appList, apps: getRunningApps(), bundleId: nil)
        guard let data = try? encoder.encode(msg), let text = String(data: data, encoding: .utf8) else { return }
        conn.send(content: wsFrame(text), completion: .contentProcessed { _ in })
    }

    private func broadcastApps() {
        let msg = WSMessage(type: .appList, apps: getRunningApps(), bundleId: nil)
        guard let data = try? encoder.encode(msg), let text = String(data: data, encoding: .utf8) else { return }
        let frame = wsFrame(text)
        for (conn, ws) in connections where ws { conn.send(content: frame, completion: .contentProcessed { _ in }) }
    }

    private func remove(_ conn: NWConnection) {
        connections.removeAll { $0.conn === conn }
        conn.cancel()
    }
}

// MARK: - Bonjour

final class BonjourService: NSObject, NetServiceDelegate {
    private var service: NetService?
    func publish() {
        service = NetService(domain: "local.", type: serviceType, name: "App Switcher", port: Int32(port))
        service?.delegate = self
        service?.publish()
    }
    func unpublish() { service?.stop() }
    func netServiceDidPublish(_ sender: NetService) { log("[server] Bonjour advertising started") }
    func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        log("[server] Bonjour publish error: \(errorDict)")
    }
}

// MARK: - Web App HTML

func webAppHTML() -> String { #"""
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no, viewport-fit=cover">
<title>App Switcher</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#1c1c1e;color:#fff;min-height:100dvh;padding:20px;-webkit-tap-highlight-color:transparent;user-select:none}
.status-bar{text-align:center;color:#8e8e93;font-size:13px;margin-bottom:16px;padding:10px;background:#2c2c2e;border-radius:10px}
.status-bar.connected{color:#30d158;background:#1a2e1f}
.status-bar.error{color:#ff453a;background:#2e1a1a}
.app-list{display:flex;flex-wrap:wrap;gap:12px;justify-content:center}
.app-item{width:128px;display:flex;flex-direction:column;align-items:center;cursor:pointer;padding:4px}
.app-item:active{opacity:0.6}
.app-item .icon{width:120px;height:120px;border-radius:22px}
.app-item .name{font-size:11px;color:#8e8e93;margin-top:4px;text-align:center;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;max-width:72px}
</style>
</head>
<body>
<div class="status-bar" id="status">Connecting...</div>
<ul class="app-list" id="list"></ul>
<script>
(function(){
var s=document.getElementById('status'),l=document.getElementById('list'),ws;
function u(c,t){s.className='status-bar '+(c||'');s.textContent=t}

function connect(){
 ws=new WebSocket('ws://'+location.host);
 ws.onopen=function(){u('connected','Connected')};
 ws.onclose=function(){u('','Disconnected — reload page')};
 ws.onerror=function(){u('error','Connection error')};
 ws.onmessage=function(e){
  try{var m=JSON.parse(e.data);if(m.type==='appList'&&m.apps)render(m.apps)}catch(err){}
 }
}

function render(a){
 l.innerHTML='';
 a.forEach(function(x){
  var li=document.createElement('li');
  li.className='app-item';
  li.innerHTML='<img class="icon" src="/icon?bundleId='+encodeURIComponent(x.bundleId)+'" onerror="this.src=\'data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 60 60%22><rect fill=%22%233a3a3c%22 width=%2260%22 height=%2260%22 rx=%2214%22/><text fill=%22%238e8e93%22 x=%2230%22 y=%2240%22 text-anchor=%22middle%22 font-size=%2228%22>'+x.name[0].toUpperCase()+'</text></svg>\'"><div class="name">'+x.name+'</div>';
  li.addEventListener('click',function(){
   ws.send(JSON.stringify({type:'focus',apps:null,bundleId:x.bundleId}));
   u('connected','Switched to '+x.name)
  });
  l.appendChild(li)
 })
}

connect()
})()
</script>
</body>
</html>
"""# }

// MARK: - Entry Point

log("=== App Switcher ===")

let server = Server()
try server.start()
let bonjour = BonjourService()
bonjour.publish()

log("[server] Open this on your phone: http://YOUR_MAC_IP:8080")
log("[server] Press Ctrl+C to stop")

RunLoop.main.run()
