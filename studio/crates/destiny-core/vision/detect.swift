// Détecteur de visages et de personnes pour Destiny Studio (framework Vision d'Apple).
//
// Usage : destiny-vision image1.jpg image2.jpg …
// Sortie (stdout) : un objet JSON par ligne, dans l'ordre des images :
//   {"file": "...", "faces": [[x, y, w, h, confiance], …], "people": [[x, y, w, h, confiance], …]}
// Coordonnées normalisées 0..1, origine en haut à gauche (Vision compte depuis le bas).
//
// Vision plutôt qu'un modèle ONNX téléchargé : rien à installer, détecteurs d'Apple
// efficaces à distance (plan large d'une scène), calcul sur le Neural Engine.
// Compilé par build.rs (swiftc) et embarqué dans destiny-core.

import Foundation
import Vision

func box(_ r: CGRect, _ c: Float) -> [Double] {
    let x = Double(r.origin.x), y = 1 - Double(r.origin.y) - Double(r.size.height)
    return [x, y, Double(r.size.width), Double(r.size.height), Double(c)].map { ($0 * 10000).rounded() / 10000 }
}

for path in CommandLine.arguments.dropFirst() {
    let url = URL(fileURLWithPath: path)
    let faces = VNDetectFaceRectanglesRequest()
    let people = VNDetectHumanRectanglesRequest()
    people.upperBodyOnly = false
    var out: [String: Any] = ["file": path, "faces": [], "people": []]
    do {
        try VNImageRequestHandler(url: url, options: [:]).perform([faces, people])
        out["faces"] = (faces.results ?? []).map { box($0.boundingBox, $0.confidence) }
        out["people"] = (people.results ?? []).map { box($0.boundingBox, $0.confidence) }
    } catch {
        out["error"] = "\(error)"
    }
    let data = try! JSONSerialization.data(withJSONObject: out)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write("\n".data(using: .utf8)!)
}
