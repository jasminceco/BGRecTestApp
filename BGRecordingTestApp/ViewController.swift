//
//  ViewController.swift
//  BGRecordingTestApp
//
//  Created by Jasmin Ceco on 16/04/2018.
//  Copyright © 2018 Jasmin Ceco. All rights reserved.
//

import UIKit
import AVFoundation
import SoundWave

class ViewController: UIViewController, AVAudioRecorderDelegate, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var trackTimeLabel: UILabel!
    @IBOutlet var recordButton: UIButton!
    @IBOutlet var clearButton: UIButton!
    @IBOutlet var audioVisualizationView: AudioVisualizationView!
    
    @IBOutlet var optionsView: UIView!
    @IBOutlet var optionsViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet var audioVisualizationTimeIntervalLabel: UILabel!
    @IBOutlet var meteringLevelBarWidthLabel: UILabel!
    @IBOutlet var meteringLevelSpaceInterBarLabel: UILabel!
    
    var myTimer: Timer!
    var backgroundTask: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
    let preferredMicOrientation = AVAudioSessionOrientationFront
    let preferredPolarPattern = AVAudioSessionPolarPatternCardioid
    var myRecordingStartDate: TimeInterval!
    var audioPlayerAndRecorder : PlayerAndRecorderViewModel!
    private var chronometer: Chronometer?
    var currentState: AudioRecodingState = .ready {
        didSet {
            self.recordButton.setImage(self.currentState.buttonImage, for: UIControlState())
            self.audioVisualizationView.audioVisualizationMode = self.currentState.audioVisualizationMode
            self.clearButton.isHidden = self.currentState == .ready || self.currentState == .playing || self.currentState == .recording
        }
    }
    var recordings : [URL] {
        get{
            do {
                let directoryContents = try FileManager.default.contentsOfDirectory(at: getDocumentsDirectory(), includingPropertiesForKeys: nil, options: [])
                return directoryContents
                
            } catch {
                print(error.localizedDescription)
            }
            return []
        }
    }
    
    enum AudioRecodingState {
        case ready
        case recording
        case recorded
        case playing
        case paused
        
        var buttonImage: UIImage {
            switch self {
            case .ready, .recording:
                return UIImage(named: "Record-Button")!
            case .recorded, .paused:
                return UIImage(named: "Play-Button")!
            case .playing:
                return UIImage(named: "Pause-Button")!
            }
        }
        
        var audioVisualizationMode: AudioVisualizationView.AudioVisualizationMode {
            switch self {
            case .ready, .recording:
                return .write
            case .paused, .playing, .recorded:
                return .read
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.estimatedRowHeight = 80
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.register(UINib(nibName: myCell.recordingsTableView, bundle: nil), forCellReuseIdentifier: myCell.recordingsTableView)
        self.tableView.tableFooterView = UIView()
    }
   

    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tableView.reloadData()
        
        self.currentState = .ready
        
        self.audioPlayerAndRecorder = PlayerAndRecorderViewModel()
        
        self.audioPlayerAndRecorder.askAudioRecordingPermission()
        
        self.audioPlayerAndRecorder.audioMeteringLevelUpdate = { [weak self] meteringLevel in
            guard let this = self, this.audioVisualizationView.audioVisualizationMode == .write else {
                return
            }
            this.audioVisualizationView.addMeteringLevel(meteringLevel)
        }
        
        self.audioPlayerAndRecorder.audioDidFinish = { [weak self] in
            self?.currentState = .recorded
            self?.audioVisualizationView.stop()
        }
        self.audioPlayerAndRecorder.elapsedTime = {
            [weak self] time in
            self?.trackTimeLabel.text = time
        }
        self.audioPlayerAndRecorder.InterruptionEnded = { [weak self] in
            DispatchQueue.global(qos: .background).async {
                print("Interruption Ended - playback should resume" , #line)
                print(self?.currentState ?? "")
                if self?.currentState == .recording || self?.currentState == .recorded{
                    self?.audioVisualizationView.reset()
                    print("[situacija 1]", #line)
                    DispatchQueue.global(qos: .utility).async {
                        self?.audioPlayerAndRecorder.startRecording { soundRecord, error in
                            if let error = error {
                                print("[situacija 2]", #line, error.localizedDescription)
                                return
                            }
                            self?.currentState = .recording
                            print("[situacija 3]", #line)
                            print("[recorder.isRecording]",AudioRecorderManager.shared.isRecording)
                        }
                    }
                }
            }
            
        }
//        self.deleteAllRecordings()
        self.tableView.reloadData()
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.audioPlayerAndRecorder.removeObserver()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        self.tableView.reloadData()
    }

    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    @IBAction func deleteAll(_ sender: UIBarButtonItem) {
        deleteAllRecordings()
        self.tableView.reloadData()
    }
    func deleteAllRecordings() {
        print("\(#function)")
        
        let docsDir =
            NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        
        let fileManager = FileManager.default
        
        do {
            let files = try fileManager.contentsOfDirectory(atPath: docsDir)
            for f in files{
                 let path = docsDir + "/" + f
                do {
                    try fileManager.removeItem(atPath: path)
                } catch {
                    NSLog("could not remove \(path)")
                    print(error.localizedDescription)
                }
            }
        } catch {
            print("could not get contents of directory at \(docsDir)")
            print(error.localizedDescription)
        }
        
    }
    
    
    // MARK: - Actions
    @IBAction func recordButtonDidTouchUpInside(_ sender: AnyObject) {
        switch self.currentState {
        case .ready:
            self.audioPlayerAndRecorder.startRecording { [weak self] soundRecord, error in
                if let error = error {
                    self?.showAlert(with: error)
                    return
                }
                
                self?.currentState = .recording
                
                self?.chronometer = Chronometer()
                self?.chronometer?.start()
            }
        case .recording:
            self.chronometer?.stop()
            self.chronometer = nil
            
            self.audioPlayerAndRecorder.currentAudioRecord!.meteringLevels = self.audioVisualizationView.scaleSoundDataToFitScreen()
            self.audioVisualizationView.audioVisualizationMode = .read
            
            do {
                try self.audioPlayerAndRecorder.stopRecording()
                self.currentState = .recorded
            } catch {
                self.currentState = .ready
                self.showAlert(with: error)
            }
        case .recorded, .paused:
            do {
                let duration = try self.audioPlayerAndRecorder.startPlaying()
                self.currentState = .playing
                self.audioVisualizationView.meteringLevels = self.audioPlayerAndRecorder.currentAudioRecord!.meteringLevels
                self.audioVisualizationView.play(for: duration)
            } catch {
                self.showAlert(with: error)
            }
        case .playing:
            do {
                try self.audioPlayerAndRecorder.pausePlaying()
                self.currentState = .paused
                self.audioVisualizationView.pause()
            } catch {
                self.showAlert(with: error)
            }
        }
    }
    
    @IBAction func clearButtonTapped(_ sender: AnyObject) {
        do {
            try self.audioPlayerAndRecorder.resetRecording()
            self.audioVisualizationView.reset()
            self.currentState = .ready
        } catch {
            self.showAlert(with: error)
        }

    }
    
    @IBAction func switchValueChanged(_ sender: AnyObject) {
        let theSwitch = sender as! UISwitch
        if theSwitch.isOn {
            self.view.backgroundColor = UIColor.mainBackgroundPurple
            self.audioVisualizationView.gradientStartColor = UIColor.audioVisualizationPurpleGradientStart
            self.audioVisualizationView.gradientEndColor = UIColor.audioVisualizationPurpleGradientEnd
        } else {
            self.view.backgroundColor = UIColor.mainBackgroundGray
            self.audioVisualizationView.gradientStartColor = UIColor.audioVisualizationGrayGradientStart
            self.audioVisualizationView.gradientEndColor = UIColor.audioVisualizationGrayGradientEnd
        }
    }
    
    @IBAction func audioVisualizationTimeIntervalSliderValueDidChange(_ sender: AnyObject) {
        let audioVisualizationTimeIntervalSlider = sender as! UISlider
        self.audioPlayerAndRecorder.audioVisualizationTimeInterval = TimeInterval(audioVisualizationTimeIntervalSlider.value)
        self.audioVisualizationTimeIntervalLabel.text = String(format: "%.2f", self.audioPlayerAndRecorder.audioVisualizationTimeInterval)
    }
    
    @IBAction func meteringLevelBarWidthSliderValueChanged(_ sender: AnyObject) {
        let meteringLevelBarWidthSlider = sender as! UISlider
        self.audioVisualizationView.meteringLevelBarWidth = CGFloat(meteringLevelBarWidthSlider.value)
        self.meteringLevelBarWidthLabel.text = String(format: "%.2f", self.audioVisualizationView.meteringLevelBarWidth)
    }
    
    @IBAction func meteringLevelSpaceInterBarSliderValueChanged(_ sender: AnyObject) {
        let meteringLevelSpaceInterBarSlider = sender as! UISlider
        self.audioVisualizationView.meteringLevelBarInterItem = CGFloat(meteringLevelSpaceInterBarSlider.value)
        self.meteringLevelSpaceInterBarLabel.text = String(format: "%.2f", self.audioVisualizationView.meteringLevelBarWidth)
    }
    
    @IBAction func optionsButtonTapped(_ sender: AnyObject) {
        let shouldExpand = self.optionsViewHeightConstraint.constant == 0
        self.optionsViewHeightConstraint.constant = shouldExpand ? 165.0 : 0.0
        UIView.animate(withDuration: 0.2) {
            self.optionsView.subviews.forEach { $0.alpha = shouldExpand ? 1.0 : 0.0 }
            self.view.layoutIfNeeded()
        }
    }
    
    // Mark: Delegate Methods
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return recordings.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell  = tableView.dequeueReusableCell(withIdentifier: myCell.recordingsTableView, for: indexPath) as! recordingsTableView
        cell.recording = self.recordings[indexPath.row]
        cell.index = indexPath.row
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print(indexPath.row)
        self.audioPlayerAndRecorder.currentAudioRecord = SoundRecord(audioFilePathLocal: self.recordings[indexPath.row], meteringLevels: [])
        do {
            try  self.audioPlayerAndRecorder.stopPlaying()
            let duration = try self.audioPlayerAndRecorder.startPlaying()
            
            self.currentState = .playing
            self.audioVisualizationView.meteringLevels = self.audioPlayerAndRecorder.currentAudioRecord!.meteringLevels
            self.audioVisualizationView.play(for: duration)
        } catch {
            self.showAlert(with: error)
        }
        
    }
    
   
    
}

extension TimeInterval {
    
    func timeIntervalAsString(_ format : String = "dd days, hh hours, mm minutes, ss seconds, sss ms") -> String {
        var asInt   = NSInteger(self)
        let ago = (asInt < 0)
        if (ago) {
            asInt = -asInt
        }
        let ms = Int(self.truncatingRemainder(dividingBy: 1) * (ago ? -1000 : 1000))
        let s = asInt % 60
        let m = (asInt / 60) % 60
        let h = ((asInt / 3600))%24
        let d = (asInt / 86400)
        
        var value = format
        value = value.replacingOccurrences(of: "hh", with: String(format: "%0.2d", h))
        value = value.replacingOccurrences(of: "mm",  with: String(format: "%0.2d", m))
        value = value.replacingOccurrences(of: "sss", with: String(format: "%0.3d", ms))
        value = value.replacingOccurrences(of: "ss",  with: String(format: "%0.2d", s))
        value = value.replacingOccurrences(of: "dd",  with: String(format: "%d", d))
        if (ago) {
            value += " ago"
        }
        return value
    }
    
}

