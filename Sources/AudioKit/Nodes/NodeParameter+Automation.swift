// Copyright AudioKit. All Rights Reserved. Revision History at http://github.com/AudioKit/AudioKit/

import AVFoundation
import CAudioKit

/// Automation functions rely on CAudioKit, so they are in this extension in case we want to
/// make a pure-swift AudioKit.
extension NodeParameter {

    /// Begin automation of the parameter.
    ///
    /// If `startTime` is nil, the automation will be scheduled as soon as possible.
    ///
    /// - Parameter events: automation curve
    /// - Parameter startTime: optional time to start automation
    public func automate(events: [AutomationEvent], startTime: AVAudioTime? = nil) {
        var lastRenderTime = avAudioNode.lastRenderTime ?? AVAudioTime(sampleTime: 0, atRate: Settings.sampleRate)

        if !lastRenderTime.isSampleTimeValid {
            if let engine = avAudioNode.engine, engine.isInManualRenderingMode {
                lastRenderTime = AVAudioTime(sampleTime: engine.manualRenderingSampleTime, atRate: Settings.sampleRate)
            } else {
                lastRenderTime = AVAudioTime(sampleTime: 0, atRate: Settings.sampleRate)
            }
        }

        var lastTime = startTime ?? lastRenderTime

        if lastTime.isHostTimeValid {
            // Convert to sample time.
            let lastTimeSeconds = AVAudioTime.seconds(forHostTime: lastRenderTime.hostTime)
            let startTimeSeconds = AVAudioTime.seconds(forHostTime: lastTime.hostTime)

            lastTime = lastRenderTime.offset(seconds: startTimeSeconds - lastTimeSeconds)
        }

        assert(lastTime.isSampleTimeValid)
        stopAutomation()

        events.withUnsafeBufferPointer { automationPtr in

            guard let automationBaseAddress = automationPtr.baseAddress else { return }

            guard let observer = ParameterAutomationGetRenderObserver(parameter.address,
                                                                      avAudioNode.auAudioUnit.scheduleParameterBlock,
                                                                      Float(Settings.sampleRate),
                                                                      Float(lastTime.sampleTime),
                                                                      automationBaseAddress,
                                                                      events.count) else { return }

            renderObserverToken = avAudioNode.auAudioUnit.token(byAddingRenderObserver: observer)
        }
    }

    /// Stop automation
    public func stopAutomation() {
        if let token = renderObserverToken {
            avAudioNode.auAudioUnit.removeRenderObserver(token)
        }
    }

    
}
