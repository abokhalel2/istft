//
//  ViewController.swift
//  istft
//
//  Created by Ibrahim Alluhaybi on 3/28/21.
//

import UIKit
import Accelerate
import AVFoundation

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let path = Bundle.main.path(forResource: "wav_file", ofType: "json")!
        let data = try! Data(contentsOf: URL(fileURLWithPath: path))
        let stft_masked:[[[[Double]]]] = try! JSONSerialization.jsonObject(with: data) as! [[[[Double]]]]

        let a1 = istft(data: stft_masked[0])
        let a2 = istft(data: stft_masked[1])

        saveWav(buf: [a1.convertToFloat, a2.convertToFloat])
        
    }
    
    func istft(data:[[[Double]]]) -> [Double] {
        let win_length = 4096
        let resultReal = data.map { $0.map { $0[0] }}
        let resultImag = data.map { $0.map { $0[1] }}

        let resultReal_transposed = resultReal.transposed
        let resultImag_Transposed = resultImag.transposed
        var FlatReal = resultReal_transposed.reduce([], +).convertToFloat
        var FlatImag = resultImag_Transposed.reduce([], +).convertToFloat

        
        var result : [Float] = [Float](repeating: 0.0, count: FlatReal.count)
        var resultComplex : UnsafeMutablePointer<DSPComplex>? = nil
        result.withUnsafeMutableBytes {
            resultComplex = $0.baseAddress?.bindMemory(to: DSPComplex.self, capacity: FlatReal.count)
        }
        
        var splitComplexBuffer = DSPSplitComplex(realp: &FlatReal, imagp: &FlatImag)
        let log2Sizes = vDSP_Length(log2f(Float(12)))
        let setupFFTz = vDSP_create_fftsetup(log2Sizes, FFTRadix(FFT_RADIX2))!
        vDSP_fft_zip(setupFFTz, &splitComplexBuffer, 1, vDSP_Length(12), FFTDirection(FFT_INVERSE));
        vDSP_ztoc(&splitComplexBuffer, 1, resultComplex!, 1, vDSP_Length(12));
        var scale : Float = 1.0;
        var copyOfResult = result;
        vDSP_vsmul(&result, 1, &scale, &copyOfResult, 1, vDSP_Length(12));
        result = copyOfResult
        
        let resultsData = result.convertToDouble
        
        let flatMatrix = Array(resultsData.chunked(into: win_length).transposed)
        let flatMatrixReduced = flatMatrix.reduce([], +)

        let nn = vDSP_Length(win_length)
        var win = [Float](repeating: 0, count: Int(nn))
        vDSP_hann_window(&win, nn, Int32(vDSP_HANN_DENORM))
        let flatwindow = win.convertToDouble
        
        let newMatrixCols = flatwindow.count
        let newMatrixRows = flatMatrix[0].count
        
        var resultCounter = [Double](repeating: 0.0, count: newMatrixCols*newMatrixRows)
        for index in 0..<resultCounter.count {
            let doub:Double = flatwindow[index/flatMatrix[0].count]
            let res:Double = flatMatrixReduced[index]
            if ((res == 0) || (doub == 0)) {
                resultCounter[index] = 0
            } else {
                resultCounter[index] = res/doub
            }
        }
        
        let flatMatrixL = Array(resultCounter.chunked(into: win_length).transposed)

        var inverseArray = [Double]()
        let odds = (0...flatMatrixL[0].count).filter { $0 % 2 == 0}
        for number in odds {
            for index in 0..<flatMatrixL.count {
                inverseArray.append(flatMatrixL[index][number])
            }
        }

        var getarr = inverseArray
        for _ in 0..<win_length/2 {
            getarr.removeFirst()
            getarr.removeLast()
        }
        
        return getarr
    }
    
    func mul(_ a:Double,_ b:Double) -> Double { return a*b }

    func saveWav(buf: [[Float]]) {
        let url = Bundle.main.url(forResource: "audio_example", withExtension: "wav")!
        let file = try! AVAudioFile(forReading: url)

        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 2, interleaved: false)!
        let pcmBuf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(buf[0].count))
        memcpy(pcmBuf?.floatChannelData?[0], buf[0], 4 * buf[0].count)
        memcpy(pcmBuf?.floatChannelData?[1], buf[1], 4 * buf[1].count)
        pcmBuf?.frameLength = UInt32(buf[0].count)

        let fileManager = FileManager.default
        do {
            let documentDirectory = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor:nil, create:false)
            var fileURL = documentDirectory.appendingPathComponent("final")
            ///try fileManager.removeItem(atPath: fileURL.path)
            try FileManager.default.createDirectory(atPath: fileURL.path, withIntermediateDirectories: true, attributes: nil)
            fileURL = fileURL.appendingPathComponent("out.wav")
            print(fileURL.path)
            let audioFile = try AVAudioFile(forWriting: fileURL, settings: file.fileFormat.settings)
            try audioFile.write(from: pcmBuf!)
        } catch {
            print(error)
        }
    }

}
