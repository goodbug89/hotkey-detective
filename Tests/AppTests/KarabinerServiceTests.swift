import XCTest
import Probe

/// 코어 서비스는 root 데몬이다. libproc `proc_name`은 비root에게 EPERM을 돌려줘 항상
/// "비활성"으로 오진했다 — 실제로는 pid 784로 돌고 있었다. Karabiner가 깔린 머신에서
/// `ps`가 보는 것과 우리 판단이 같은지 고정한다. 없는 머신(CI)에서는 건너뛴다.
final class KarabinerServiceTests: XCTestCase {
    func testMatchesProcessTable() throws {
        let ps = Process(); ps.executableURL = URL(fileURLWithPath: "/bin/ps")
        ps.arguments = ["-Ao", "comm"]
        let pipe = Pipe(); ps.standardOutput = pipe
        try ps.run()
        // 반드시 읽고 나서 기다린다. 먼저 기다리면 ps 출력이 파이프 버퍼(64KB)를 넘는 순간
        // ps는 쓰기에서, 우리는 waitUntilExit에서 서로를 기다린다 — 실제로 10분 멈췄다.
        let out = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        ps.waitUntilExit()
        let running = out.contains("Karabiner-Core-Service")
        guard running else { throw XCTSkip("이 머신에 Karabiner 코어 서비스가 없다") }
        XCTAssertTrue(KarabinerService.isActive(), "ps에는 Karabiner-Core-Service가 있는데 비활성으로 판단했다")
    }
}
