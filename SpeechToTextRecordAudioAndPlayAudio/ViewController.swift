//
//  ViewController.swift
//  SpeechToTextRecordAudioAndPlayAudio
//
//  Created by ramil on 10.10.2019.
//  Copyright © 2019 com.ri. All rights reserved.
//

import UIKit
import Speech
import AVFoundation
 
 
class ViewController: UIViewController, AVAudioRecorderDelegate {
    
    @IBOutlet weak var recordDisplay: UIButton!
    @IBOutlet weak var playDisplay: UIButton!
    @IBOutlet weak var textView: UITextView!
    
    
    
    // Audio section
    var file:Int = 0
    var AudioPlayer:AVAudioPlayer!
    var AudioSession:AVAudioSession!
    var AudioRecorder:AVAudioRecorder!
    
    // Speech to Text section
    var lang: String = "en-US"
    var SpeechRecognitionTask: SFSpeechRecognitionTask?
    var RecognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    var AudioEngine = AVAudioEngine()
    var SpeechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: "en-US"))
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Initialize AudioSession
        AudioSession = AVAudioSession.sharedInstance()
        
        // to solve 'required condition is false: IsFormatSampleRateAndChannelCountValid(format)'
            do {
                try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [])
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print(error)
            }
        
        // To get permission from user
        AVAudioSession.sharedInstance().requestRecordPermission{(hasPermission) in
            if hasPermission
            {
                self.textView.text = "Ready to speak?"
            }
        }
        // To check any saved file?
        if let number:Int = UserDefaults.standard.object(forKey: "recording") as? Int
        {
            file = number
        }
        
        
        
        // Speech to Text Section
        recordDisplay.isEnabled = false
        SpeechRecognizer?.delegate = self as? SFSpeechRecognizerDelegate
        SpeechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: lang))
        SFSpeechRecognizer.requestAuthorization { (authStatus) in
            
            var isButtonEnabled = false
            
            switch authStatus {
            case .authorized:
                isButtonEnabled = true
                
            case .restricted:
                isButtonEnabled = false
                print("Restricted")
                
            case .notDetermined:
                isButtonEnabled = false
                print("notdetermined")
                
            case .denied:
                isButtonEnabled = false
                print("Access denied")
                
            @unknown default: break
                // ...
            }
            
            OperationQueue.main.addOperation() {
                self.recordDisplay.isEnabled = isButtonEnabled
            }
        }
    }
    // Audio Section Function that gets path to directory
    func getDirectory() -> URL
    {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentDirectory = paths[0]
        return documentDirectory
    }
    
    @IBAction func englishBTN(_ sender: Any) {
        lang = "en-US"
        SpeechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: lang))
        textView.text = "Ready to speak?"
    }
    
    @IBAction func japaneseBTN(_ sender: Any) {
        lang = "ja-JP"
        SpeechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: lang))
        textView.text = "Ready to speak?"
    }
    @IBAction func recordBTN(_ sender: Any) {
        
        // Speech To Text section
        SpeechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: lang))
        if AudioEngine.isRunning {
            self.AudioEngine.stop()
            self.RecognitionRequest?.endAudio()
        } else {
            startSpeechRecording()
        }
        
        startAudioRecording()
        
    }
    func startAudioRecording() {
        // Audio Section: If active file saved?
        if AudioRecorder == nil{
            file = 1
            let filename = getDirectory().appendingPathComponent("\(file).m4a")
            let settings = [AVSampleRateKey: 12000,
                            AVNumberOfChannelsKey: 1,
                            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue]
            
            // Start audio recording
            do{
                AudioRecorder = try AVAudioRecorder(url: filename, settings: settings)
                AudioRecorder.delegate = self
                AudioRecorder.record()
                recordDisplay.setTitle("STOP", for: .normal)
                print("recording now")
            }
            catch
            {
                showAlert(title: "Error", message: "Please try again")
            }
        } else{
            // Stopping audio recording
            AudioRecorder.stop()
            AudioRecorder = nil
            // To save recording
            UserDefaults.standard.set(file, forKey: "recording")
            recordDisplay.setTitle("Start", for: .normal)
            
            // Starting playing
            let path = getDirectory().appendingPathComponent("\(file).m4a")
            print("file\(file)")
            
            do
            {
                AudioPlayer = try AVAudioPlayer(contentsOf: path)
                AudioPlayer.play()
                // Only play once
                AudioPlayer?.numberOfLoops = 0
                // Set the volume of playback here.
                AudioPlayer?.volume = 10.0
                print("playing now")
            }
            catch
            {
                showAlert(title: "Error", message: "Please try again")
            }
        }
        
    }
    
    
    func startSpeechRecording() {
        
        // Cancel the previous task if it's running.
        if SpeechRecognitionTask != nil {
            SpeechRecognitionTask?.cancel()
            SpeechRecognitionTask = nil
        }
        
        RecognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = AudioEngine.inputNode
        
        guard let RecognitionRequest = RecognitionRequest else {
            fatalError("Error in Recognition")
        }
        
        RecognitionRequest.shouldReportPartialResults = true
        
        SpeechRecognitionTask = SpeechRecognizer?.recognitionTask(with: RecognitionRequest, resultHandler: { (result, error) in
            
            var FinalResult = false
            
            if result != nil {
                self.textView.text = result?.bestTranscription.formattedString
                FinalResult = (result?.isFinal)!
            }
            
            if error != nil || FinalResult {
                self.RecognitionRequest = nil
                self.SpeechRecognitionTask = nil
                self.AudioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recordDisplay.isEnabled = true
                
            }
        })
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.RecognitionRequest?.append(buffer)
        }
        
        AudioEngine.prepare()
        
        do {
            try AudioEngine.start()
        } catch {
            print("AudioEngine didn't initialize")
        }
    }
    
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            recordDisplay.isEnabled = true
        } else {
            recordDisplay.isEnabled = false
        }
    }
    
    @IBAction func playBTN(_ sender: Any) {
        let path = getDirectory().appendingPathComponent("\(file).m4a")
        do
        {
            AudioPlayer = try AVAudioPlayer(contentsOf: path)
            AudioPlayer.play()
            // Only play once
            AudioPlayer?.numberOfLoops = 0
            // Set the volume of playback here.
            AudioPlayer?.volume = 10.0
            print("play button pressed now")
        }
        catch
        {
            showAlert(title: "Error", message: "Please try again")
        }
    }
    
    
    // To display Alert Message
    func showAlert(title:String, message:String)
    {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    
    
    
}
 
