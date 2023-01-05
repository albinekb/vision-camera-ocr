import AVFoundation
import MLKitTextRecognition
import MLKitVision
import Vision

@objc(OCRFrameProcessorPlugin)
public class OCRFrameProcessorPlugin: NSObject, FrameProcessorPluginBase {
    static var _textRecognizer: TextRecognizer?
    
  private static func getBlockArray(_ blocks: [TextBlock]) -> [[String: Any]] {

    var blockArray: [[String: Any]] = []

    for block in blocks {
      blockArray.append([
        "text": block.text,
        //"recognizedLanguages": getRecognizedLanguages(block.recognizedLanguages),
        "cornerPoints": getCornerPoints(block.cornerPoints),
        "frame": getFrame(block.frame),
        //"lines": getLineArray(block.lines),
      ])
    }

    return blockArray
  }

  private static func getLineArray(_ lines: [TextLine]) -> [[String: Any]] {

    var lineArray: [[String: Any]] = []

    for line in lines {
      lineArray.append([
        "text": line.text,
        "recognizedLanguages": getRecognizedLanguages(line.recognizedLanguages),
        "cornerPoints": getCornerPoints(line.cornerPoints),
        "frame": getFrame(line.frame),
        "elements": getElementArray(line.elements),
      ])
    }

    return lineArray
  }

  private static func getElementArray(_ elements: [TextElement]) -> [[String: Any]] {

    var elementArray: [[String: Any]] = []

    for element in elements {
      elementArray.append([
        "text": element.text,
        "cornerPoints": getCornerPoints(element.cornerPoints),
        "frame": getFrame(element.frame),
      ])
    }

    return elementArray
  }

  private static func getRecognizedLanguages(_ languages: [TextRecognizedLanguage]) -> [String] {

    var languageArray: [String] = []

    for language in languages {
      guard let code = language.languageCode else {
        print("No language code exists")
        break
      }
      languageArray.append(code)
    }

    return languageArray
  }

  private static func getCornerPoints(_ cornerPoints: [NSValue]) -> [[String: CGFloat]] {

    var cornerPointArray: [[String: CGFloat]] = []

    for cornerPoint in cornerPoints {
      guard let point = cornerPoint as? CGPoint else {
        print("Failed to convert corner point to CGPoint")
        break
      }
      cornerPointArray.append(["x": point.x, "y": point.y])
    }

    return cornerPointArray
  }

  private static func getFrame(_ frameRect: CGRect) -> [String: CGFloat] {

    let offsetX = (frameRect.midX - ceil(frameRect.width)) / 2.0
    let offsetY = (frameRect.midY - ceil(frameRect.height)) / 2.0

    let x = frameRect.maxX + offsetX
    let y = frameRect.minY + offsetY

    return [
      "x": frameRect.midX + (frameRect.midX - x),
      "y": frameRect.midY + (y - frameRect.midY),
      "width": frameRect.width,
      "height": frameRect.height,
      "boundingCenterX": frameRect.midX,
      "boundingCenterY": frameRect.midY,
    ]
  }
    
    static func createScanner(_ args: [Any]!) throws {
        if (_textRecognizer == nil) {
            let options = TextRecognizerOptions()
            _textRecognizer = TextRecognizer.textRecognizer(options: options)
        }
    }
    

  @objc
  public static func callback(_ frame: Frame!, withArgs args: [Any]!) -> Any! {

    guard let previewSize = args[0] as? [String: Any] else {
      return nil
    }
      guard let captureSize = args[1] as? [String: Any] else {
        return nil
      }
      let previewWidth = previewSize["width"] as! NSNumber
      let previewHeight = previewSize["height"] as! NSNumber
      let previewTop = previewSize["top"] as! NSNumber
        let captureWidth = captureSize["width"] as! NSNumber
        let captureHeight = captureSize["height"] as! NSNumber
  
    if let imageBuffer = CMSampleBufferGetImageBuffer(frame.buffer) {
        do {
            try self.createScanner(args)
        }  catch _ {
            return nil
        }
      let ciimage = CIImage(cvPixelBuffer: imageBuffer)
        //debugPrint("ciimage : ", ciimage.extent.size.width, )
        let previewRect =  AVMakeRect(
            aspectRatio: CGSize(width: previewWidth.doubleValue, height: previewHeight.doubleValue),
            insideRect: CGRect(x: 0, y: 0, width: ciimage.extent.size.width, height: ciimage.extent.height))
            //debugPrint("croppedSize", croppedSize, separator: " : ")
            //debugPrint("previewSize", previewSize, separator: " : ")
        guard var image = self.convert(cmage: ciimage, orientation: .up, cropImageSize: previewRect) else {
            return nil
        }
      var croppedImage = image
        debugPrint("image", image.size.width, image.size.height, separator: " : ")
      var previewImageRect = CGRect.zero
      if let previewSize = args[0] as? [String: Any] {
   
        let croppedSize = AVMakeRect(
          aspectRatio: CGSize(width: previewWidth.doubleValue, height: previewHeight.doubleValue),
          insideRect: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
          debugPrint("croppedSize", croppedSize, separator: " : ")
          debugPrint("previewSize", previewSize, separator: " : ")
          
        let takenCGImage = image.cgImage
          
        let cropCGImage = takenCGImage?.cropping(to: croppedSize)
        guard let cropCGImage = cropCGImage else {
            debugPrint("Did not crop image")
          return nil
        }
          debugPrint("scale", image.scale, separator: " : ")
        image = UIImage(
          cgImage: cropCGImage, scale: image.scale, orientation: image.imageOrientation)

          debugPrint("captureSize", captureSize, separator: " : ")
        let scaleWidth = captureWidth.doubleValue / previewWidth.doubleValue
          debugPrint("scaleWidth", scaleWidth, separator: " : ")
        let widthImage = image.size.width * scaleWidth
        let aspecRatioCaptureView = captureHeight.doubleValue / captureWidth.doubleValue
        let heightImage = widthImage * aspecRatioCaptureView
          
        let captureTop = previewSize["top"] as! NSNumber
          
          
        previewImageRect = caculateCropImageRect(
            originImageSize: image.size, cropImageSize: CGSize(width: widthImage, height: heightImage), previewTop: previewTop.doubleValue, captureTop: captureTop.doubleValue
        )
          debugPrint("previewImageRect", previewImageRect, separator: " : ")
        croppedImage = cropImage(image: image, rect: previewImageRect)
      }
      let visionImage = VisionImage(image: croppedImage)
      do {
        let result = try _textRecognizer!
          .results(in: visionImage)
        return [
          "result": [
            "text": result.text,
            "blocks": getBlockArray(result.blocks),
            "xAxis": previewImageRect.origin.x,
            "yAxis": previewImageRect.origin.y,
            "frameWidth": image.size.width,
            "frameHeight": image.size.height,
          ]
        ]
      } catch let error {
        print("Failed to recognize text with error: \(error.localizedDescription).")
        return nil
      }
    } else {
      print("Failed to get image buffer from sample buffer.")
      return nil
    }
  }
    
    static var cgImageContext: CIContext?
    
    
    static func createImageContext() throws {
        if (cgImageContext == nil) {
            if let mtlDevice = MTLCreateSystemDefaultDevice() {
              cgImageContext = CIContext.init(mtlDevice: mtlDevice)
              
            } else {
                cgImageContext = CIContext(options: nil)
              
            }
        }
    }

    private static func convert(cmage: CIImage, orientation: UIImage.Orientation, cropImageSize: CGRect) -> UIImage? {
      
      do {
          try self.createImageContext()
      }  catch _ {
          return nil
      }

    let cgImage = cgImageContext!.createCGImage(cmage, from: cropImageSize)!
    let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
    return image
  }

    private static func caculateCropImageRect(originImageSize: CGSize, cropImageSize: CGSize, previewTop: Double, captureTop: Double)
    -> CGRect
  {
    let scaleWidth = originImageSize.width / cropImageSize.width
    let originXImage = (originImageSize.width / 2 - cropImageSize.width / 2)
    let originYImage = (originImageSize.height / 2 - cropImageSize.height / 2) + scaleWidth
    let rect: CGRect = CGRect(
      x: originXImage, y: originYImage, width: cropImageSize.width, height: cropImageSize.height
    ).integral

    return rect
  }

  private static func cropImage(image: UIImage, rect: CGRect) -> UIImage {
    let cgimage = image.cgImage!

    let imageRef: CGImage = cgimage.cropping(to: rect)!
    let resultImage: UIImage = UIImage(
      cgImage: imageRef, scale: image.scale, orientation: image.imageOrientation)

    return resultImage
  }

}
