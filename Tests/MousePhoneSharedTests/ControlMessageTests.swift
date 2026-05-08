import Testing
@testable import MousePhoneShared

@Test func controlMessagesRoundTripThroughJSON() throws {
    let messages: [ControlMessage] = [
        .pointerMove(dx: 12.5, dy: -4),
        .airMouseMove(dx: 7.25, dy: -3.5),
        .click(button: .left, phase: .single),
        .scroll(dx: 0, dy: 24),
        .volume(delta: -1),
        .ping(timestamp: 123),
        .pairRequest(.init(code: "123456", deviceName: "iPhone")),
        .pairAck(.init(code: "123456", deviceName: "MacBook"))
    ]

    for message in messages {
        let decoded = try ControlMessage.decoded(from: message.encoded())
        #expect(decoded == message)
    }
}
