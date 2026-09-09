import Darwin
import Engine

/// Karabiner 코어 서비스가 살아 있는지.
///
/// root로 도는 launchd 데몬이라 NSRunningApplication에는 나타나지 않는다. libproc의
/// `proc_name`도 못 쓴다 — 비root 호출자에게 root 프로세스의 이름을 주지 않는다(실측:
/// pid 784에 대해 반환 0, errno 1 EPERM). `sysctl KERN_PROC_ALL`은 모든 프로세스의
/// `p_comm`을 준다. 단 MAXCOMLEN(16)에서 잘리므로 "Karabiner-Core-Service"는
/// "Karabiner-Core-S"로 온다 — 그래서 전체 이름을 16자로 자른 것과 비교한다.
public enum KarabinerService {
    static let fullName = "Karabiner-Core-Service"
    static let truncatedName = String(fullName.prefix(16))   // p_comm과 같은 절단

    public static func isActive() -> Bool {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size = 0
        guard sysctl(&mib, 4, nil, &size, nil, 0) == 0, size > 0 else { return false }
        var procs = [kinfo_proc](repeating: kinfo_proc(), count: size / MemoryLayout<kinfo_proc>.stride + 8)
        guard sysctl(&mib, 4, &procs, &size, nil, 0) == 0 else { return false }
        let count = size / MemoryLayout<kinfo_proc>.stride
        for i in 0..<count {
            var p = procs[i]
            let comm = withUnsafePointer(to: &p.kp_proc.p_comm) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN) + 1) { String(cString: $0) }
            }
            if comm == truncatedName || comm == fullName { return true }
        }
        return false
    }
}
