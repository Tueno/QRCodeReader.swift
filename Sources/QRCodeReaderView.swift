/*
 * QRCodeReader.swift
 *
 * Copyright 2014-present Yannick Loriot.
 * http://yannickloriot.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

import AVFoundation
import UIKit

final public class QRCodeReaderView: UIView, QRCodeReaderDisplayable {
  public lazy var overlayLayer: QRCodeReaderViewOverlay? = {
    let ol = ReaderOverlayLayer()
    ol.backgroundColor                           = UIColor.clear.cgColor
    ol.masksToBounds                             = true

    return ol
  }()

  public let cameraView: UIView = {
    let cv = UIView()

    cv.clipsToBounds                             = true
    cv.translatesAutoresizingMaskIntoConstraints = false

    return cv
  }()

  public lazy var cancelButton: UIButton? = {
    let cb = UIButton()

    cb.translatesAutoresizingMaskIntoConstraints = false
    cb.setTitleColor(.gray, for: .highlighted)

    return cb
  }()

  public lazy var switchCameraButton: UIButton? = {
    let scb = SwitchCameraButton()

    scb.translatesAutoresizingMaskIntoConstraints = false

    return scb
  }()

  public lazy var toggleTorchButton: UIButton? = {
    let ttb = ToggleTorchButton()

    ttb.translatesAutoresizingMaskIntoConstraints = false

    return ttb
  }()

  private weak var reader: QRCodeReader?
  private var rectOfInterest: CGRect?

  public var cameraDimensions: CMVideoDimensions?

  public func setupComponents(with builder: QRCodeReaderViewControllerBuilder) {
    self.reader               = builder.reader
    self.rectOfInterest     = builder.rectOfInterest
    reader?.lifeCycleDelegate = self

    addComponents()

    cancelButton?.isHidden       = !builder.showCancelButton
    switchCameraButton?.isHidden = !builder.showSwitchCameraButton
    toggleTorchButton?.isHidden  = !builder.showTorchButton
    overlayLayer?.isHidden        = !builder.showOverlayView

    guard let cb = cancelButton, let scb = switchCameraButton, let ttb = toggleTorchButton else { return }

    let views = ["cv": cameraView, "cb": cb, "scb": scb, "ttb": ttb]

    addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[cv]|", options: [], metrics: nil, views: views))

    if builder.showCancelButton {
      addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[cv][cb(40)]|", options: [], metrics: nil, views: views))
      addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-[cb]-|", options: [], metrics: nil, views: views))
    }
    else {
      addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[cv]|", options: [], metrics: nil, views: views))
    }

    if builder.showSwitchCameraButton {
      addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-[scb(50)]", options: [], metrics: nil, views: views))
      addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:[scb(70)]|", options: [], metrics: nil, views: views))
    }

    if builder.showTorchButton {
      addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-[ttb(50)]", options: [], metrics: nil, views: views))
      addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[ttb(70)]", options: [], metrics: nil, views: views))
    }
  }

  public override func layoutSubviews() {
    super.layoutSubviews()
  }

  // MARK: - Scan Result Indication

  func startTimerForBorderReset() {
    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
      self.overlayLayer?.setState(.normal)
    }
  }

  func addRedBorder() {
    self.startTimerForBorderReset()

    self.overlayLayer?.setState(.wrong)
  }

  func addGreenBorder() {
    self.startTimerForBorderReset()

    self.overlayLayer?.setState(.valid)
  }

  @objc public func setNeedsUpdateOrientation() {
    setNeedsDisplay()

    overlayLayer?.setNeedsDisplay()

    if let connection = reader?.previewLayer.connection, connection.isVideoOrientationSupported {
      let application                    = UIApplication.shared
      let orientation                    = UIDevice.current.orientation
      let supportedInterfaceOrientations = application.supportedInterfaceOrientations(for: application.keyWindow)

      connection.videoOrientation = QRCodeReader.videoOrientation(deviceOrientation: orientation, withSupportedOrientations: supportedInterfaceOrientations, fallbackOrientation: connection.videoOrientation)
    }
  }

  // MARK: - Convenience Methods

  private func addComponents() {
#if swift(>=4.2)
    let notificationName = UIDevice.orientationDidChangeNotification
#else
    let notificationName = NSNotification.Name.UIDeviceOrientationDidChange
#endif

    NotificationCenter.default.addObserver(self, selector: #selector(self.setNeedsUpdateOrientation), name: notificationName, object: nil)

    addSubview(cameraView)

    if let ol = overlayLayer {
      layer.addSublayer(ol)
    }

    if let scb = switchCameraButton {
      addSubview(scb)
    }

    if let ttb = toggleTorchButton {
      addSubview(ttb)
    }

    if let cb = cancelButton {
      addSubview(cb)
    }

    if let reader = reader {
      cameraView.layer.insertSublayer(reader.previewLayer, at: 0)

      setNeedsUpdateOrientation()
    }
  }
}

extension QRCodeReaderView: QRCodeReaderLifeCycleDelegate {
  func readerDidStartScanning() {
    setNeedsUpdateOrientation()
  }

  func readerDidStopScanning() {}

  func updateCameraInputDimensions(dimensions: CMVideoDimensions?) {
    guard let dimensions = dimensions else {
      // Facllback
      DispatchQueue.main.async {
        // TODO: TBI
      }
      return
    }
    DispatchQueue.main.async {
      // Adjust rect of intersect.
      if let rectOfInterest = self.rectOfInterest {
        // TODO: TBI
        let adjustedRectOfInterest: CGRect = .zero
        self.reader?.metadataOutput.rectOfInterest = adjustedRectOfInterest
        (self.overlayLayer as? ReaderOverlayLayer)?.rectOfInterest = adjustedRectOfInterest
      }

      // Adjust preview size to visible rect.
      let widthDimen = CGFloat(dimensions.width)
      let heightDimen = CGFloat(dimensions.height)

      let scale: CGFloat

      let widthScale = self.bounds.width / widthDimen
      let heightScale = self.bounds.height / heightDimen

      if widthScale > heightScale {
        scale = widthScale
      } else {
        scale = heightScale
      }

      let rect = CGRect(origin: .zero, size: .init(width: widthDimen * scale,
                                                   height: heightDimen * scale))
      self.reader?.previewLayer.frame = rect
      self.overlayLayer?.bounds = rect
      self.overlayLayer?.position = .init(x: CGRectGetMidX(self.bounds),
                                          y: CGRectGetMidY(self.bounds))
      self.overlayLayer?.drawOverlay()
    }
  }
}
