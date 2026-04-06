//
//  UniversalScript.swift
//  ManicJIT-script
//
//  Created by Stossy11 on 20/3/2026.
//
import Foundation
import ManicEmuCore

#if SIDE_LOAD
extension FileManager {
    func filePath(atPath path: String, withLength length: Int) -> String? {
        guard let file = try? contentsOfDirectory(atPath: path).filter({ $0.count == length }).first else { return nil }
        return "\(path)/\(file)"
    }
}

public extension ProcessInfo {
    var hasTXM: Bool {
        { if let boot = FileManager.default.filePath(atPath: "/System/Volumes/Preboot", withLength: 36), let file = FileManager.default.filePath(atPath: "\(boot)/boot", withLength: 96) { return access("\(file)/usr/standalone/firmware/FUD/Ap,TrustedExecutionMonitor.img4", F_OK) == 0 } else { return (FileManager.default.filePath(atPath: "/private/preboot", withLength: 96).map { access("\($0)/usr/standalone/firmware/FUD/Ap,TrustedExecutionMonitor.img4", F_OK) == 0 }) ?? false } }()
    }
}


@_silgen_name("BreakSendJITScript")
func BreakSendJITScript(_ script: UnsafePointer<CChar>!, _ length: size_t)

func handler(sig: Int32, info: UnsafeMutablePointer<siginfo_t>?, context: UnsafeMutableRawPointer?) {
    guard let context = context else { return }
    let uc = context.bindMemory(to: ucontext_t.self, capacity: 1)
    uc.pointee.uc_mcontext.pointee.__ss.__pc += 4
    uc.pointee.uc_mcontext.pointee.__ss.__x.0 = 0
}

// here to stop app from crashing when app launched without JIT attached on 26 TXM
func JIT26BreakpointHandler() {
    var sa = sigaction()
    sa.sa_flags = SA_SIGINFO
    
    sa.__sigaction_u.__sa_sigaction = handler
    
    sigaction(SIGTRAP, &sa, nil)
}
#endif

func setupUniversalScript(gameType: GameType) {
#if SIDE_LOAD
    guard #available(iOS 19.0, *) else { return }
    guard ProcessInfo.processInfo.hasTXM else { return }
    
    JIT26BreakpointHandler()
    
    var script: String? = nil
    switch gameType {
    case ._3ds:
        script = """
          legacyCommands[0x70] = function(b) {};
          legacyCommands[0x71] = function(b) {};
      """
    case .n64:
        script = """
          legacyCommands[0x70] = function(b) {};
          legacyCommands[0x71] = function(b) {};
          legacyCommands[0x69] = manicN64Breakpoint;
          continuesWithSignal = true;
          var n64JitRequests = 0;
          function manicN64Breakpoint(brkResponse) {
              n64JitRequests++;
              var jitAddr = x0;
              var size = x1 > 0n ? x1 : 0x10000n;
              log('[N64] JIT Request #' + n64JitRequests + ' addr=0x' + jitAddr.toString(16) + ' size=0x' + size.toString(16));
              var result = prepare_memory_region(Number(jitAddr), Number(size));
              log('[N64] prepare_memory_region result: ' + result);
          }
      """
    default: return
    }
    
    guard let script else { return }
    
    BreakSendJITScript(script, script.count)
#endif
}




