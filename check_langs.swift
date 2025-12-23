import Vision

if #available(macOS 13.0, *) {
    let request = VNRecognizeTextRequest()
    request.revision = VNRecognizeTextRequestRevision3
    request.recognitionLevel = .accurate
    do {
        let langs = try request.supportedRecognitionLanguages()
        print("Supported languages (Rev 3): \(langs)")
    } catch {
        print("Error getting languages: \(error)")
    }
} else {
    print("MacOS 13+ required for Rev 3 check in this script")
}
