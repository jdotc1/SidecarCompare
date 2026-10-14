import Foundation

/// Deliberately synthetic; not obtained from patient data or a real scanner examination.
public enum ExampleSidecars {
    public static let a = #"""
    {
      "Modality": "MR",
      "Manufacturer": "Synthetic scanner vendor",
      "ManufacturersModelName": "Research demonstration",
      "MagneticFieldStrength": 1.5,
      "ProtocolName": "SYNTHETIC_T2_BASELINE",
      "SeriesDescription": "Synthetic example only",
      "RepetitionTime": 5.2,
      "EchoTime": 0.085,
      "FlipAngle": 90,
      "SliceThickness": 3.0,
      "SpacingBetweenSlices": 3.0,
      "PhaseEncodingDirection": "j-",
      "PixelBandwidth": 200,
      "EchoTrainLength": 16,
      "ImageType": ["ORIGINAL", "PRIMARY", "M"],
      "ConversionSoftware": "dcm2niix",
      "ConversionSoftwareVersion": "synthetic-fixture",
      "ExampleVendorMetadata": {"Revision": 1, "OptionalValue": null}
    }
    """#
    public static let b = #"""
    {
      "Modality": "MR",
      "Manufacturer": "Synthetic scanner vendor",
      "ManufacturersModelName": "Research demonstration",
      "MagneticFieldStrength": 1.5,
      "ProtocolName": "SYNTHETIC_T2_FOLLOWUP",
      "SeriesDescription": "Synthetic example only",
      "RepetitionTime": 5.2,
      "EchoTime": 0.08501,
      "FlipAngle": 90.0,
      "SliceThickness": 2.5,
      "SpacingBetweenSlices": 2.5,
      "PhaseEncodingDirection": "j",
      "PixelBandwidth": 210,
      "EchoTrainLength": 16,
      "ImageType": ["ORIGINAL", "PRIMARY", "M"],
      "ConversionSoftware": "dcm2niix",
      "ConversionSoftwareVersion": "synthetic-fixture",
      "ExampleVendorMetadata": {"Revision": "1", "NewFlag": true}
    }
    """#
    public static func documents() throws -> (SidecarDocument, SidecarDocument) {
        (SidecarDocument(value: try JSONParser.parse(Data(a.utf8)), displayName: "Synthetic baseline.json"),
         SidecarDocument(value: try JSONParser.parse(Data(b.utf8)), displayName: "Synthetic follow-up.json"))
    }
}
