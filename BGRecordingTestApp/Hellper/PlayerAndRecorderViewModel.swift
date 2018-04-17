//
//  PlayerAndRecorderViewModel.swift
//  BGRecordingTestApp
//
//  Created by Jasmin Ceco on 16/04/2018.
//  Copyright © 2018 Jasmin Ceco. All rights reserved.
//

import Foundation
import AVFoundation

struct SoundRecord {
	var audioFilePathLocal: URL?
	var meteringLevels: [Float]?
}

final class PlayerAndRecorderViewModel {
	var audioVisualizationTimeInterval: TimeInterval = 0.05 // Time interval between each metering bar representation
	
	var currentAudioRecord: SoundRecord?
	private var isPlaying = false
    var elapsedTime: ((String)->())?
	var audioMeteringLevelUpdate: ((Float) -> ())?
	var audioDidFinish: (() -> ())?
    var InterruptionEnded: (() -> ())?
	init() {
		// notifications update metering levels
		NotificationCenter.default.addObserver(self, selector: #selector(PlayerAndRecorderViewModel.didReceiveMeteringLevelUpdate),
			name: .audioPlayerManagerMeteringLevelDidUpdateNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(PlayerAndRecorderViewModel.didReceiveMeteringLevelUpdate),
			name: .audioRecorderManagerMeteringLevelDidUpdateNotification, object: nil)
		
		// notifications audio finished
		NotificationCenter.default.addObserver(self, selector: #selector(PlayerAndRecorderViewModel.didFinishRecordOrPlayAudio),
			name: .audioPlayerManagerMeteringLevelDidFinishNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(PlayerAndRecorderViewModel.didFinishRecordOrPlayAudio),
			name: .audioRecorderManagerMeteringLevelDidFinishNotification, object: nil)
        AudioRecorderManager.shared.recorderElapsedTime = { time in
            self.elapsedTime!(time)
        }
        AudioPlayerManager.shared.recorderElapsedTime = { time in
            self.elapsedTime!(time)
        }
        registerForNotifications()
	}
    
    @objc func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
            let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSessionInterruptionType(rawValue: typeValue) else {
                return
        }
        switch type {
        case .began:
            print("Interruption began, take appropriate actions (save state, update user interface)",#function , #line)
        case .ended:
            guard let optionsValue =
                notification.userInfo![AVAudioSessionInterruptionOptionKey] as? UInt else {
                    return
            }
            let options = AVAudioSessionInterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                InterruptionEnded!()
            }
        }
        
    }
    
    func registerForNotifications() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleInterruption),
                                               name: .AVAudioSessionInterruption,
                                               object: AVAudioSession.sharedInstance())
    }
    
    
    deinit {
        print("-------- PlayerAndRecorderViewModel DEINIT --------------")
    }
	
    func removeObserver(){
        print(#function, #line)
         audioVisualizationTimeInterval = 0
         currentAudioRecord = nil
   
         elapsedTime = nil
         audioMeteringLevelUpdate = nil
         audioDidFinish = nil
        do{
            try self.stopRecording()
        }catch{
           print(error.localizedDescription)
        }
        NotificationCenter.default.removeObserver(self)
    }
	// MARK: - Recording
	
	func askAudioRecordingPermission(completion: ((Bool) -> Void)? = nil) {
		return AudioRecorderManager.shared.askPermission(completion: completion)
	}
	
	func startRecording(completion: @escaping (SoundRecord?, Error?) -> Void) {
		AudioRecorderManager.shared.startRecording(with: self.audioVisualizationTimeInterval, completion: { [weak self] url, error in
			guard let url = url else {
				completion(nil, error!)
				return
			}
			
			self?.currentAudioRecord = SoundRecord(audioFilePathLocal: url, meteringLevels: [])
			print("sound record created at url \(url.absoluteString))")
			completion(self?.currentAudioRecord, nil)
		})
	}
	
	func stopRecording() throws {
		try AudioRecorderManager.shared.stopRecording()
	}
	
	func resetRecording() throws {
		try AudioRecorderManager.shared.reset()
		self.isPlaying = false
		self.currentAudioRecord = nil
	}
	
	// MARK: - Playing
	
    func stopPlaying() throws {
        if self.isPlaying {
            return try AudioPlayerManager.shared.stop()
        }
    }
    func startPlaying() throws -> TimeInterval {
		guard let currentAudioRecord = self.currentAudioRecord else {
			throw AudioErrorType.audioFileWrongPath
		}
       
		if self.isPlaying {
			return try AudioPlayerManager.shared.resume()
		} else {
			guard let audioFilePath = currentAudioRecord.audioFilePathLocal else {
				fatalError("tried to unwrap audio file path that is nil")
			}
			
			self.isPlaying = true
			return try AudioPlayerManager.shared.play(at: audioFilePath, with: self.audioVisualizationTimeInterval)
		}
	}
	
	func pausePlaying() throws {
		try AudioPlayerManager.shared.pause()
	}
	
	// MARK: - Notifications Handling
	
	@objc private func didReceiveMeteringLevelUpdate(_ notification: Notification) {
		let percentage = notification.userInfo![audioPercentageUserInfoKey] as! Float
		self.audioMeteringLevelUpdate?(percentage)
	}
	
	@objc private func didFinishRecordOrPlayAudio(_ notification: Notification) {
		self.audioDidFinish?()
	}
}
