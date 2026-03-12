import Foundation
import Combine

/// Manages the lifecycle of a single SSH port-forward process.
final class TunnelSession: ObservableObject, Identifiable {
    let id: UUID

    @Published private(set) var config: TunnelConfig
    @Published private(set) var status: TunnelStatus = .stopped
    @Published private(set) var pid: Int32?
    @Published private(set) var lastError: String = ""

    private var process: Process?
    private var errorPipe: Pipe?
    /// Keeps SSH stdin open so the remote shell won't exit on EOF when -N is disabled.
    private var stdinPipe: Pipe?
    /// Set before intentionally stopping so the termination handler knows not to report an error.
    private var intentionallyStopping = false
    /// Temp SSH_ASKPASS script written for password-auth sessions; deleted on stop.
    private var askPassScriptURL: URL?
    /// Accumulated stderr output for real-time error detection.
    private var stderrBuffer = ""
    /// Connection timeout work item.
    private var connectTimeoutItem: DispatchWorkItem?
    /// Current auto-reconnect attempt count; reset on successful connection.
    private var reconnectAttempt = 0
    /// Pending reconnect work item; cancelled on intentional stop.
    private var reconnectWorkItem: DispatchWorkItem?

    init(config: TunnelConfig) {
        self.id = config.id
        self.config = config
    }

    // MARK: – Config updates

    /// Update only the pin flag without restarting the tunnel.
    func setPinned(_ pinned: Bool) {
        config.isPinned = pinned
    }

    func updateConfig(_ newConfig: TunnelConfig) {
        let wasRunning = status.isRunning
        let dying = stop()          // stop() now returns the old Process if one was running
        config = newConfig
        guard wasRunning else { return }
        if let dying {
            // Wait on a background thread for the old SSH process to actually release
            // the port before starting the new one; otherwise we get "Address already in use".
            DispatchQueue.global(qos: .utility).async { [weak self] in
                dying.waitUntilExit()
                DispatchQueue.main.async { self?.start() }
            }
        } else {
            start()
        }
    }

    // MARK: – Lifecycle

    func start() {
        let isReconnecting: Bool
        if case .reconnecting = status {
            isReconnecting = true
        } else {
            isReconnecting = false
            reconnectAttempt = 0
        }
        guard !status.isRunning || isReconnecting else { return }
        intentionallyStopping = false
        if !isReconnecting { status = .connecting }
        lastError = ""

        // For password auth, write a temp SSH_ASKPASS helper script before launching.
        if config.authMethod == .password {
            guard let url = writeAskPassScript() else {
                let msg = String(localized: "No password saved. Please edit the tunnel and enter a password.")
                lastError = msg
                status = .stopped   // config issue, not a connection failure — keep dot gray
                return
            }
            askPassScriptURL = url
        }

        let args = buildArguments()
        let sshProcess = Process()
        sshProcess.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        sshProcess.arguments = args

        // When launched from Finder/Dock the shell environment is absent (no SSH_AUTH_SOCK).
        var processEnv = ProcessInfo.processInfo.environment
        if (processEnv["SSH_AUTH_SOCK"] ?? "").isEmpty,
           let sock = launchctlGetenv("SSH_AUTH_SOCK"), !sock.isEmpty {
            processEnv["SSH_AUTH_SOCK"] = sock
        }
        // Point SSH at the askpass script so it can obtain the password non-interactively.
        if let scriptURL = askPassScriptURL {
            processEnv["SSH_ASKPASS"]         = scriptURL.path
            processEnv["SSH_ASKPASS_REQUIRE"] = "force"
            if (processEnv["DISPLAY"] ?? "").isEmpty { processEnv["DISPLAY"] = "none" }
        }
        sshProcess.environment = processEnv

        let errPipe = Pipe()
        let inPipe = Pipe()
        sshProcess.standardInput = inPipe
        sshProcess.standardOutput = Pipe()
        sshProcess.standardError = errPipe
        stdinPipe = inPipe
        errorPipe = errPipe
        stderrBuffer = ""

        // Monitor stderr in real-time to detect auth success/failure.
        errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let self else { return }
            if let text = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.stderrBuffer += text
                    self.checkStderr()
                }
            }
        }

        sshProcess.terminationHandler = { [weak self] proc in
            guard let self else { return }
            // Stop real-time reading and collect any remaining data.
            errPipe.fileHandleForReading.readabilityHandler = nil
            let remaining = errPipe.fileHandleForReading.readDataToEndOfFile()
            if let text = String(data: remaining, encoding: .utf8), !text.isEmpty {
                self.stderrBuffer += text
            }
            // Clean up temp askpass script immediately after SSH exits.
            if let url = self.askPassScriptURL {
                try? FileManager.default.removeItem(at: url)
                self.askPassScriptURL = nil
            }
            let msg = Self.cleanDebugLines(self.stderrBuffer)
            DispatchQueue.main.async {
                self.connectTimeoutItem?.cancel()
                self.connectTimeoutItem = nil
                self.pid = nil
                if self.intentionallyStopping || proc.terminationStatus == 0 {
                    self.lastError = ""
                    self.status = .stopped
                } else if self.config.isAutoReconnect && !self.shouldSkipReconnect(msg) {
                    // Auto-reconnect: schedule retry with exponential backoff
                    self.reconnectAttempt += 1
                    let attempt = self.reconnectAttempt
                    let display = msg.isEmpty ? String(format: String(localized: "Exited with code %d"), proc.terminationStatus) : msg
                    self.lastError = display
                    self.status = .reconnecting(attempt: attempt)
                    self.scheduleReconnect(attempt: attempt)
                } else {
                    let display = msg.isEmpty ? String(format: String(localized: "Exited with code %d"), proc.terminationStatus) : msg
                    self.lastError = display
                    self.status = .error(display)
                }
                self.intentionallyStopping = false
                self.stderrBuffer = ""
            }
        }

        do {
            try sshProcess.run()
            process = sshProcess
            pid = sshProcess.processIdentifier

            // Timeout: if no auth success/failure detected in 30s, mark as error.
            let timeout = DispatchWorkItem { [weak self] in
                guard let self, case .connecting = self.status else { return }
                let msg = String(localized: "Connection timed out")
                self.lastError = msg
                self.status = .error(msg)
                self.stop()
            }
            connectTimeoutItem = timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 30.0, execute: timeout)
        } catch {
            if let url = askPassScriptURL {
                try? FileManager.default.removeItem(at: url)
                askPassScriptURL = nil
            }
            status = .error(error.localizedDescription)
            lastError = error.localizedDescription
        }
    }

    /// Stops the tunnel. Returns the Process object if it was still running so the
    /// caller can `waitUntilExit()` on a background thread before restarting.
    func clearError() {
        lastError = ""
        if case .error = status { status = .stopped }
    }

    @discardableResult
    func stop() -> Process? {
        intentionallyStopping = true
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        reconnectAttempt = 0
        connectTimeoutItem?.cancel()
        connectTimeoutItem = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil
        stdinPipe = nil
        let dying: Process?
        if let process, process.isRunning {
            process.terminate()
            dying = process
        } else {
            dying = nil
        }
        process = nil
        errorPipe = nil
        pid = nil
        lastError = ""
        status = .stopped
        stderrBuffer = ""
        if let url = askPassScriptURL {
            try? FileManager.default.removeItem(at: url)
            askPassScriptURL = nil
        }
        return dying
    }

    deinit { stop() }

    // MARK: – Helpers

    /// Patterns in stderr that indicate the connection has failed.
    private static let errorPatterns = [
        "permission denied",
        "authentication failed",
        "no more authentication methods",
        "connection refused",
        "connection timed out",
        "host key verification failed",
        "could not resolve hostname",
        "network is unreachable",
        "no route to host",
        "too many authentication failures",
    ]

    /// Check accumulated stderr for SSH auth success or known error messages.
    private func checkStderr() {
        let lower = stderrBuffer.lowercased()

        // Detect authentication success from ssh -v output.
        if lower.contains("authenticated to") {
            if case .connecting = status {
                connectTimeoutItem?.cancel()
                connectTimeoutItem = nil
                reconnectAttempt = 0
                status = .connected
            } else if case .reconnecting = status {
                connectTimeoutItem?.cancel()
                connectTimeoutItem = nil
                reconnectAttempt = 0
                status = .connected
            }
            return
        }

        // Detect errors — check even if status is .connected (connection can drop).
        for pattern in Self.errorPatterns {
            if lower.contains(pattern) {
                connectTimeoutItem?.cancel()
                connectTimeoutItem = nil
                let msg = Self.cleanDebugLines(stderrBuffer)
                lastError = msg
                status = .error(msg)
                return
            }
        }
    }

    /// Strip ssh debug lines (debug1:, debug2:, etc.) from stderr output
    /// to show only the meaningful error message to the user.
    private static func cleanDebugLines(_ raw: String) -> String {
        raw.components(separatedBy: .newlines)
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return !trimmed.isEmpty
                    && !trimmed.hasPrefix("debug")
                    && !trimmed.hasPrefix("OpenSSH")
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Errors that indicate a configuration / auth problem — reconnecting won't help.
    private static let noReconnectPatterns = [
        "permission denied",
        "authentication failed",
        "no more authentication methods",
        "host key verification failed",
        "too many authentication failures",
    ]

    /// Returns true if the error message indicates reconnecting would be futile.
    private func shouldSkipReconnect(_ msg: String) -> Bool {
        let lower = msg.lowercased()
        return Self.noReconnectPatterns.contains { lower.contains($0) }
    }

    /// Schedule a reconnect attempt with exponential backoff (3s, 6s, 12s … capped at 60s).
    private func scheduleReconnect(attempt: Int) {
        let delay = min(3.0 * pow(2.0, Double(attempt - 1)), 60.0)
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            // Only proceed if still in reconnecting state (not manually stopped).
            if case .reconnecting = self.status {
                self.start()
            }
        }
        reconnectWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func buildArguments() -> [String] {
        var args: [String] = []

        if config.noRemoteCommand { args += ["-N", "-T"] }
        args += ["-v"]   // verbose: needed to detect "Authenticated to" in stderr
        args += ["-o", "ServerAliveInterval=15"]
        args += ["-o", "ServerAliveCountMax=3"]
        args += ["-o", "ExitOnForwardFailure=yes"]
        args += ["-o", "StrictHostKeyChecking=accept-new"]

        switch config.authMethod {
        case .agentOrDefault:
            args += ["-o", "BatchMode=yes"]
            args += ["-o", "UseKeychain=yes"]

        case .identityFile:
            args += ["-o", "BatchMode=yes"]
            args += ["-o", "UseKeychain=yes"]
            if !config.identityFile.isEmpty {
                args += ["-i", (config.identityFile as NSString).expandingTildeInPath]
                args += ["-o", "IdentitiesOnly=yes"]
            }

        case .password:
            args += ["-o", "PubkeyAuthentication=no"]
            args += ["-o", "PreferredAuthentications=password,keyboard-interactive"]
        }

        // Add forwarding arguments for each enabled rule
        for rule in config.forwardRules where rule.isEnabled {
            switch rule.type {
            case .local where rule.localPort > 0 && rule.remotePort > 0:
                args += ["-L", rule.argument]
            case .remote where rule.localPort > 0 && rule.remotePort > 0:
                args += ["-R", rule.argument]
            case .dynamic where rule.localPort > 0:
                args += ["-D", rule.argument]
            default:
                break
            }
        }

        if config.enableCompression {
            args += ["-C"]
        }

        args += ["-p", "\(config.sshPort)"]

        let dest = config.sshUser.isEmpty
            ? config.sshHost
            : "\(config.sshUser)@\(config.sshHost)"
        args.append(dest)

        if !config.additionalArgs.isEmpty {
            args += config.additionalArgs
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
        }

        return args
    }

    /// Write a temp shell script that prints the Keychain-stored password to stdout.
    /// SSH calls this script via SSH_ASKPASS instead of prompting interactively.
    private func writeAskPassScript() -> URL? {
        guard let password = KeychainHelper.getPassword(forID: config.id),
              !password.isEmpty else { return nil }

        // Escape single quotes so the password embeds safely in a sh single-quoted string.
        let escaped = password.replacingOccurrences(of: "'", with: "'\\''")
        let script   = "#!/bin/sh\nprintf '%s' '\(escaped)'\n"

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ssh-askpass-\(config.id.uuidString).sh")
        do {
            try script.write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700],
                                                  ofItemAtPath: url.path)
            return url
        } catch {
            return nil
        }
    }

    /// Query launchd for an environment variable — the only reliable way to get
    /// SSH_AUTH_SOCK when the app was launched from Finder rather than a terminal.
    private func launchctlGetenv(_ key: String) -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        proc.arguments = ["getenv", key]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        guard (try? proc.run()) != nil else { return nil }
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
