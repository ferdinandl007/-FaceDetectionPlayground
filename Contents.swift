import Foundation
import AVFoundation
import CoreGraphics
import Vision
import PlaygroundSupport
import UIKit

protocol VisageDelegate: class {
    func mouseDidMove(position: CGPoint)
    func faceDidSmile(faceFeature: CIFaceFeature)
    func eyeDidClosed(faceFeature: CIFaceFeature)
    
}

extension Array where Element: Numeric {
    /// Returns the total sum of all elements in the array
    var total: Element { return reduce(0, +) }
    
    
}

extension Array where Element: BinaryInteger {
    /// Returns the average of all elements in the array
    var average: Double {
        return isEmpty ? 0 : Double(Int(total)) / Double(count)
    }
}

extension Array where Element: FloatingPoint {
    /// Returns the average of all elements in the array
    var average: Element {
        return isEmpty ? 0 : total / Element(count)
    }
}


public class Visage: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    weak var delegate: VisageDelegate?
    
    // set up the size of the camera view  and initialise as NSView
    fileprivate var visageCameraView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 640.0, height: 480.0))
    
    // assigning the face detector as a CI detector
    fileprivate var faceDetector : CIDetector?
    
    // assigning videoDataOutputQueue as DispatchQueue which is an optionalcalX
    fileprivate var videoDataOutputQueue : DispatchQueue?
    
    // initialising output as a capture video output§
    fileprivate var output = AVCaptureVideoDataOutput()
    
    // assigning the camera preview layer
    fileprivate var cameraPreviewLayer : AVCaptureVideoPreviewLayer?
    // initialise  AVCaptureSession
    fileprivate var captureSession : AVCaptureSession = AVCaptureSession()
    
    // initialise capture layer as CALayer
    fileprivate var captureLayer: CALayer = CALayer()
    
    // assigning sample buffer
    fileprivate var sampleBuffers: CMSampleBuffer?
    
    // initialising the dispatch Queue used to asynchronously process the face tracking
    fileprivate let dispatchQueue = DispatchQueue(label: "com.wwdc_project_2019")
    
    // initialising the is user smiling variable to true
    fileprivate var isSmile = true
    
    // initialising face tracking ends  to false
    fileprivate var  faceTrackingEnds = false
    
    // used to determine the speed of the mouse
    public var speed: CGFloat = 40.0
    
    // used to set the sensitivity of the mouse
    public var sensitivity: CGFloat = 3
    
    // arrange to  contain the 100 readings captured at the beginning of  the session
    public var calibrationData = [CGFloat]()
    // used to calculate the true centre
    fileprivate var calX = [CGFloat]()
    fileprivate var calY = [CGFloat]()
    
    // variable containing the true centre of the mouth 2D  coordinates
    public var trueCentre = CGPoint()
    
    // determine if calibration  has to be redone
    fileprivate var hasEnded = false
    
    //  this sets the initial position of the mouse
    fileprivate var  mouseLocation = CGPoint(x: 655.927419354839, y: 655.927419354839)
    
    fileprivate var canClikc = true
    
    // saving screen size in this var
    fileprivate var rect = CGRect()
    
    fileprivate var faceIDs = [Int32]()
    
    fileprivate var ispause = false
    
    fileprivate var selection = 0
    
    fileprivate var lastRightEyeBlink: Date?
    fileprivate var lastLeftEyeBlink: Date?
    fileprivate var lastSmile: Date?
    
    //  this method is called when the class is initialised
    override init() {
        super.init()
        
        //  calls the camera set up method
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: // The user has previously granted access to the camera.
             self.captureSetup()
            
        case .notDetermined: // The user has not yet been asked for camera access.
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self.captureSetup()
                }
            }
            
        case .denied: // The user has previously denied access.
            return
        case .restricted: // The user can't grant access due to restrictions.
            return
        }

        
        //   initialising the face detection options as a dictionary
        var faceDetectorOptions : [String : Any]?
        
        //  assigning faceDetectorOptions to set the accuracy high
        faceDetectorOptions = [CIDetectorAccuracy: CIDetectorAccuracyHigh,
                               CIDetectorTracking: true]
        
        // Initialising the CI detector  to detect faces with  options said to high accuracy
        self.faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: faceDetectorOptions)
        
        //  get screen size and places them asking the centre  of the screen  For start-up
            rect = visageCameraView.frame
            mouseLocation = CGPoint(x: rect.size.width / 2, y: rect.size.height / 2)
        
    }
    
    //  method used to start running the capture session
    public func beginFaceDetection() {
        //  this starts the face tracking loop
        self.faceTrackingEnds = false
        // This starts the capture session so the camera will turn on now
        self.captureSession.startRunning()
        //  this starts the face tracking
        self.faceDetection()
        
        
    }
    
    // Method to end  the capture session as well as terminate the face tracking loop
    public func endFaceDetection() {
        
        //  this will stop the capture session so the camera will turn off
        self.captureSession.stopRunning()
        
        //  this terminates  the face tracking loop
        self.faceTrackingEnds = true
        
        //  get everything set up for recalibration
        calY = []
        calX = []
        hasEnded = false
        
    }
    
    //  captures setup method  sets up everything for the life camera view
    fileprivate func captureSetup () {
        
        //  assigns  the capture device input
        var input : AVCaptureDeviceInput
        
        //  devices will represent the media capture devices  present on this machine such as cameras and mics
         var _frontCamera: AVCaptureDevice?
      
        
        // this loop will go through all the different media capture methods on this machine
        
        _frontCamera = AVCaptureDevice.default(.builtInTrueDepthCamera, for: AVMediaType.video, position: .front)
        
        do {
            // if yes  we set up the video input
            guard let x = _frontCamera else { return }
            input = try AVCaptureDeviceInput(device: x) as AVCaptureDeviceInput
            
            // and add the input to the capture session
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
        }
        catch {
            print(error.localizedDescription)
        }
        
        //  here we specify the settings we will use to encode the input
        guard let videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable as? String: Int(kCVPixelFormatType_32BGRA)] as? [String : Any] else {
            print("videoSettings")
            return
        }
        self.output.videoSettings = videoSettings
        
        //  this will make sure that late frames will be discarded and will not clog up the frame rate
        self.output.alwaysDiscardsLateVideoFrames = true
        
        //  puts the video encoding on our video output Queue
        self.videoDataOutputQueue = DispatchQueue(label: "VideoDataOutputQueue", attributes: [])
        self.output.setSampleBufferDelegate(self, queue: self.videoDataOutputQueue!)
        
        //  now we add our output to are captureSession
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
        }
        
        // assigning capture layer  to our life video  capture layer
        self.captureLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        
        //  makes sure that visageCameraView  has a layer so we can  later  apply to life video to it
        //visageCameraView.wantsLayer = true
        
        //  assigning are life video view to visageCameraView
       // visageCameraView.layer = captureLayer
    }
    
    //  this method is called  during every frame
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection){
        
        //  assigning a sample buffer  to the current captured  sample buffer so we can use it later
        self.sampleBuffers = sampleBuffer
    }
    
    
    fileprivate func allFeatures(sample: CMSampleBuffer) -> [CIFeature]?{
        
        //  casting the sample buffer to CMSampleBuffer and assigning it to pixelBuffer
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sample) else {
            print("pixelBuffer")
            return nil
            
        }
        guard let attachments = CMCopyDictionaryOfAttachments(allocator: kCFAllocatorDefault, target: sample, attachmentMode: kCMAttachmentMode_ShouldPropagate) as? [CIImageOption : Any] else {
            print("attachments")
            return nil
            
        }
        
        
        let ciImage = CIImage(cvImageBuffer: pixelBuffer, options: attachments )
        
        
        //  setting up the options  for the  CI detector
        let options: [String : Any] = [CIDetectorImageOrientation: 1, CIDetectorSmile: true, CIDetectorEyeBlink: true, CIDetectorTracking: true]
        
        //  assign an instance of CIdetector to allFeatures and initialise with the CIimage as well as the options
        let allFeatures = self.faceDetector?.features(in: ciImage, options: options)
        
        // if allfeatures is not equal to nil. if yes assign allfeatures to features otherwise return
        return allFeatures
        
    }
    
    public func mouseDidMove(position: CGPoint){
        delegate?.mouseDidMove(position: position)
    }
    
    public func faceDidSmile(faceFeature: CIFaceFeature) {
        delegate?.faceDidSmile(faceFeature: faceFeature)
    }
    
    public func eyeDidClosed(faceFeature: CIFaceFeature) {
        delegate?.eyeDidClosed(faceFeature: faceFeature)
    }
    
    public func time(time: Date? , delay: Double) -> Bool {
        guard let lastBlink = time else { return false }
        
        let t = Date().timeIntervalSince(lastBlink)
        
        if t > delay {
            return true
        } else {
            return false
        }
    }
    
    public func mouseWillMoveTo(position: CGPoint) {
        
        //  determines if the mouse is meant to be moved or to ignore
        if abs((trueCentre.x - position.x) / trueCentre.x) > (self.calibrationData[0] * sensitivity) || abs((trueCentre.y - position.y ) / trueCentre.y) > (self.calibrationData[1] * abs(sensitivity - 1)) {
            
            // This calculates the Delta on the face to the true centre  and then applies a corresponding vector to the mouse.
            let new = CGPoint(x: mouseLocation.x + (((trueCentre.x - position.x) / trueCentre.x) * speed), y: mouseLocation.y + ((trueCentre.y - position.y) / trueCentre.y) * speed)
            
            // checking x component is not out of reach of display
            if new.x > 0 && new.x < rect.maxX  {
                mouseLocation.x = new.x
            }
            // checking y component is not out of reach of display
            if new.y > 0 && new.y < rect.maxY  {
                mouseLocation.y = new.y
            }
            
            if !ispause {
                //  updating the mouse position by pushing to the OSX  event queue event you
               // let c = CGEvent.init(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: mouseLocation, mouseButton: .left)
                //c?.post(tap: .cgSessionEventTap)
                
            }
        }
    }
    
    public func faceWillSmileClick(faceFeature: CIFaceFeature) {
        // Checks if  a smile is equal to  the user's smile 3 and if clicking is enabled
        
        if faceFeature.hasSmile && canClikc {
            if lastSmile == nil {
                lastSmile = Date()
            }
            
            if time(time: lastSmile, delay: 0.3) {
                lastSmile = Date()
               // let x = CGEvent.init(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition:  mouseLocation, mouseButton: .left)
                //x?.post(tap: .cgSessionEventTap )
                print("click")
                
                
               // let y = CGEvent.init(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: mouseLocation, mouseButton: .left)
               // y?.post(tap: .cgSessionEventTap )
                
            }
            
        } else {
            lastSmile = nil
        }
        
    }
    
    
    
    public func eyeWillClick(faceFeature: CIFaceFeature) {
        //   Checks if  a smile is equal to  the user's smile 3 and if clicking is enabled
        if faceFeature.rightEyeClosed && !faceFeature.leftEyeClosed && canClikc {
            if lastRightEyeBlink == nil {
                lastRightEyeBlink = Date()
            }
            lastLeftEyeBlink = nil
            if time(time: lastRightEyeBlink, delay: 0.3) {
                lastRightEyeBlink = Date()
               // let x = CGEvent.init(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition:  mouseLocation, mouseButton: .left)
               // x?.post(tap: .cgSessionEventTap )
                print("click")
                
                
                //let y = CGEvent.init(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: mouseLocation, mouseButton: .left)
               // y?.post(tap: .cgSessionEventTap )
            }
            
            
        } else {
            lastRightEyeBlink = nil
        }
    }
    
    fileprivate func faceDetection(){
        
        let group = DispatchGroup()
        group.enter()
        
        // setting up dispatchQueue
        dispatchQueue.async {
            
            //  checking if sample buffer  is equal to nil if not assign its value to sample
            if let sample = self.sampleBuffers {
                
                
                //if allfeatures is not equal to nil. if yes assign allfeatures to features otherwise return
                guard let features = self.allFeatures(sample: sample) else { return }
                
                
                for face in features {
                    if let faceID = face as? CIFaceFeature {
                        self.faceIDs.append(faceID.trackingID)
                    }
                }
                
                // loop to cycle through all features
                for  feature in features {
                    
                    // checks if the feature is a CIFaceFeature if yes assign feature to face feature and go on.
                    if let faceFeature = feature as? CIFaceFeature {
                        // To check every calibration is needed
                        if !self.hasEnded {
                            //  check if enough data has been captured
                            if self.calX.count > 100 {
                                
                                //  calculate  min and max for X and Y
                                guard let calXMax = self.calX.max() else {return}
                                guard let calXMin = self.calX.min() else {return}
                                guard let calYMax = self.calY.max() else {return}
                                guard let calYMin = self.calY.min() else {return}
                                
                                //  The said calibration data to a empty array
                                self.calibrationData = []
                                //  append the difference between minimum maximum as a  percentage Delta to  calibrated data.
                                self.calibrationData.append((calXMax - calXMin) / calXMax)
                                self.calibrationData.append((calYMax - calYMin) / calYMax)
                                print(self.calibrationData)
                                
                                //  calculating the true centre of the mouse by taking the average of all captured coordinates
                                self.trueCentre = CGPoint(x: self.calX.average, y: self.calY.average)
                                print("trueCentre = ",self.trueCentre)
                                
                                self.hasEnded = true
                            } else {
                                //  add capture data to X and Y
                                self.calX.append(faceFeature.mouthPosition.x)
                                self.calY.append(faceFeature.mouthPosition.y)
                                print(faceFeature.mouthPosition.y)
                            }
                            
                        } else {
                            // to check that we are tracking the correct face
                            if faceFeature.trackingID == self.faceIDs.min() {
                                // update mouse position
                                self.delegate?.mouseDidMove(position: faceFeature.mouthPosition)
                                
                                switch self.selection {
                                case 1:
                                    self.eyeDidClosed(faceFeature: faceFeature)
                                default:
                                    self.faceDidSmile(faceFeature: faceFeature)
                                }
                                
                                self.faceIDs.removeAll()
                            }
                        }
                    }
                }
            }
            //  tells the dispatch group  that everything is finished processing
            group.leave()
        }
        
        //  this gets called after the above code has finished processing  to recall and process  basically Loop
        group.notify(queue: .main) {
            
            //  checks if the Loop need to be terminated
            if !self.faceTrackingEnds {
                self.faceDetection()
            }
        }
    }
    
    //  function to set sensitivity and speed
    public func setSensitivity(sensitivityint: Float, speeds: Int) {
        speed = CGFloat(speeds)
        sensitivity = CGFloat(sensitivityint)
        
    }
    
    public func setCanClick(click: Bool){
        canClikc = click
    }
    
    public func setSelection(select: Int) {
        selection = select
    }
    
    
}// end of class


class Camara: UIView , VisageDelegate{
    
    // initialising the NSView
    fileprivate let camara = UIView()
    
    // assigning the Visage class to smileRec
    fileprivate var camaraRec: Visage!
    
    // this method gets called when the class is initialised
    override init(frame: CGRect) {
        
        //  gets the size of the frame from the initialiser
        super.init(frame: frame)
        
        //  adds are smileView as a Subview of NSView
        self.addSubview(camara)
        
        //  sets up constraints
        self.translatesAutoresizingMaskIntoConstraints = false
        
        //  initialising the Visage class
        camaraRec = Visage()
        
        camaraRec.delegate = self
        
        //  gets the  life  view from the visage class
        let cameraView = camaraRec.visageCameraView
        
        //  this will  add our life camera view (cameraView) and will add it as a subview to are class
        self.addSubview(cameraView)
    }
    
    func mouseDidMove(position: CGPoint) {
        camaraRec.mouseWillMoveTo(position: position)
    }
    
    func faceDidSmile(faceFeature: CIFaceFeature) {
        camaraRec.faceWillSmileClick(faceFeature: faceFeature)
    }
    
    func eyeDidClosed(faceFeature: CIFaceFeature) {
        camaraRec.eyeWillClick(faceFeature: faceFeature)
    }
    
    //  starts the camera view and  face tracking
    public func faceTracking(yes: Bool){
        if yes {
            camaraRec.beginFaceDetection()
        } else {
            camaraRec.endFaceDetection()
        }
    }
    
    public func setSpeed(sensitivityint: Float,speed: Int) {
        camaraRec.setSensitivity(sensitivityint: sensitivityint, speeds: speed)
    }
    
    public func setCanClick(click: Bool){
        camaraRec.setCanClick(click: click)
    }
    
    public func setSelection(select: Int) {
        camaraRec.setSelection(select: select)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
}

// now all we have to do is set the execution mode of the  playground to indefinite
PlaygroundPage.current.needsIndefiniteExecution = false

//  and are view to the playground
let cam = Camara(frame: CGRect(x: 0, y: 0, width: 640.0, height: 360))

cam.setCanClick(click: true)
cam.faceTracking(yes: true)
 PlaygroundPage.current.liveView = cam

