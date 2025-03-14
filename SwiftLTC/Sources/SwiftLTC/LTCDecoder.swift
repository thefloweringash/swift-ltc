import AVFAudio
import libltc

public enum LTCWriteError: Error {
    case unsupportedFormat
}

public struct LTCDecoder: ~Copyable {
    fileprivate var pointer: UnsafeMutablePointer<libltc.LTCDecoder>

    public init?(apv: Int32 = 1920, queueSize: Int32 = 32) {
        guard let pointer = ltc_decoder_create(apv, queueSize) else { return nil }
        self.pointer = pointer
    }

    deinit {
        ltc_decoder_free(pointer)
    }

    public mutating func decode(fromURL url: URL, body: (inout LTCFrameExt) -> Bool) throws {
        let file = try AVAudioFile(forReading: url)

        switch file.processingFormat.commonFormat {
        case .pcmFormatInt16:
            try decode(file: file, format: Int16Buffer.self, body: body)
        case .pcmFormatFloat32:
            try decode(file: file, format: Float32Buffer.self, body: body)
        default:
            throw LTCWriteError.unsupportedFormat
        }
    }

    private mutating func decode<X: Format>(file: AVAudioFile, format: X.Type, body: (inout LTCFrameExt) -> Bool) throws {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 1024) else {
            throw LTCWriteError.unsupportedFormat
        }

        var frame = LTCFrameExt()
        while file.framePosition != file.length {
            let bufferPosition = file.framePosition
            try file.read(into: buffer)

            format.write(to: self, from: buffer, position: bufferPosition)

            while ltc_decoder_read(pointer, &frame) != 0 {
                let cont = body(&frame)
                if !cont { return }
            }
        }
    }
}

public struct LTCBGFlags: OptionSet, Sendable {
    public init(rawValue: LTC_BG_FLAGS.RawValue) {
        self.rawValue = rawValue
    }

    public let rawValue: LTC_BG_FLAGS.RawValue

    public static let useDate = LTCBGFlags(rawValue: LTC_USE_DATE.rawValue)
    public static let TCClock = LTCBGFlags(rawValue: LTC_TC_CLOCK.rawValue)
    public static let BGFDontTouch = LTCBGFlags(rawValue: LTC_BGF_DONT_TOUCH.rawValue)
    public static let noParity = LTCBGFlags(rawValue: LTC_NO_PARITY.rawValue)
}

public extension LTCFrameExt {
    // TODO: not mutating, just passing by pointer
    mutating func toSMTPETimecode(flags: LTCBGFlags) -> SMPTETimecode {
        var timecode = SMPTETimecode()
        ltc_frame_to_time(&timecode, &ltc, Int32(flags.rawValue))
        return timecode
    }
}

struct Float32Buffer {}
struct Int16Buffer {}

protocol Format {
    static func write(to decoder: borrowing LTCDecoder, from buffer: AVAudioPCMBuffer, position: AVAudioFramePosition)
}

extension Int16Buffer: Format {
    static func write(to decoder: borrowing LTCDecoder, from buffer: AVAudioPCMBuffer, position: AVAudioFramePosition) {
        ltc_decoder_write_s16(decoder.pointer, buffer.int16ChannelData!.pointee, Int(buffer.frameLength), Int64(position))
    }
}

extension Float32Buffer: Format {
    static func write(to decoder: borrowing LTCDecoder, from buffer: AVAudioPCMBuffer, position: AVAudioFramePosition) {
        ltc_decoder_write_float(decoder.pointer, buffer.floatChannelData!.pointee, Int(buffer.frameLength), Int64(position))
    }
}
