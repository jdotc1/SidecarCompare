import Foundation

public enum FieldCategory: String, CaseIterable, Sendable, Identifiable {
    case timing = "Timing"
    case acquisition = "Acquisition"
    case encoding = "Encoding"
    case scanner = "Scanner"
    case geometry = "Geometry metadata"
    case provenance = "Provenance / descriptive"
    case other = "Other"
    public var id: String { rawValue }
}

public struct FieldInfo: Sendable {
    public enum Shape: Sendable {
        case number, numberOrArray, numberArray, raw
        func accepts(_ value: JSONValue) -> Bool {
            switch (self, value) {
            case (.raw, _), (.number, .number), (.numberOrArray, .number): return true
            case (.numberOrArray, .array(let values)), (.numberArray, .array(let values)):
                return !values.isEmpty && values.allSatisfy { if case .number = $0 { true } else { false } }
            default: return false
            }
        }
    }
    public let key: String
    public let category: FieldCategory
    public let unit: String?
    public let shape: Shape
    public let source: String
    public let explanation: String
    public var allowsTolerance: Bool { unit != nil }
    public func accepts(_ value: JSONValue?) -> Bool { value.map { shape.accepts($0) } ?? true }
}

/// A curated annotation table, not a BIDS schema/validator or an exhaustive dcm2niix dictionary.
public enum FieldCatalog {
    public static let revision = "2026-10-14.1"
    public static let fields: [String: FieldInfo] = {
        var result = [String: FieldInfo]()
        func add(_ keys: [String], _ category: FieldCategory, _ unit: String? = nil,
                 _ shape: FieldInfo.Shape = .raw, _ source: String = "BIDS", _ explanation: String = "") {
            for key in keys {
                result[key] = FieldInfo(key: key, category: category, unit: unit, shape: shape,
                                       source: source, explanation: explanation)
            }
        }
        add(["RepetitionTime", "RepetitionTimeExcitation", "InversionTime", "DwellTime", "EffectiveEchoSpacing", "TotalReadoutTime", "DelayTime", "AcquisitionDuration"], .timing, "s", .number)
        add(["EchoTime", "PostLabelingDelay", "RepetitionTimePreparation"], .timing, "s", .numberOrArray)
        add(["SliceTiming", "VolumeTiming"], .timing, "s", .numberArray)
        add(["FlipAngle"], .acquisition, "deg", .numberOrArray)
        add(["MagneticFieldStrength"], .scanner, "T", .number)
        add(["SliceThickness", "SpacingBetweenSlices"], .geometry, "mm", .number, "dcm2niix")
        add(["ImagingFrequency"], .scanner, "MHz", .number, "dcm2niix")
        add(["PixelBandwidth"], .encoding, "Hz", .number, "dcm2niix", "Use the converter's documented quantity; no Hz/pixel or reciprocal-spacing inference is performed.")
        add(["EstimatedEffectiveEchoSpacing", "EstimatedTotalReadoutTime", "DerivedVendorReportedEchoSpacing", "RepetitionTimeInversion"], .timing, "s", .number, "dcm2niix")
        add(["PhaseEncodingDirection", "SliceEncodingDirection", "PartialFourier", "ParallelReductionFactorInPlane", "MultibandAccelerationFactor", "InPlanePhaseEncodingDirectionDICOM", "ReconMatrixPE", "AcquisitionMatrixPE"], .encoding)
        add(["EchoNumber", "EchoTrainLength", "NumberOfAverages", "MRAcquisitionType", "ScanningSequence", "SequenceVariant", "ScanOptions", "SequenceName", "ImageType", "Modality"], .acquisition)
        add(["Manufacturer", "ManufacturersModelName", "ReceiveCoilName", "SoftwareVersions", "DeviceSerialNumber", "StationName"], .scanner)
        add(["ImageOrientationPatientDICOM", "PatientPosition"], .geometry)
        add(["ConversionSoftware", "ConversionSoftwareVersion", "ProtocolName", "SeriesDescription", "StudyDescription", "InstitutionName", "AcquisitionTime", "AcquisitionDateTime"], .provenance)
        return result
    }()
    public static func info(forTopLevelKey key: String) -> FieldInfo? { fields[key] }
}
