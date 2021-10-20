//
//  DataEntryToggle.swift
//  DataEntryHelpers
//
//  Created by Douglas Boberg
//  Copyright © 2016 Douglas Boberg. All rights reserved.
//
// Rewritten from Objective-C to Swift 5 by Douglas Boberg on October 20, 2021
//

import Foundation
import UIKit


open class DataEntryToggle: UIControl, UIGestureRecognizerDelegate {
	private var _titles:[String]?
	public	var titles:[String]! {
		get { return _titles }
		set(titles) {
			_titles = titles
			self.values = titles	// default values are titles

			// titles changed so remove old labels
			for v:UIView? in gutter.subviews {
				v?.removeFromSuperview()
			}

			// create new labels so they'll be ready during layoutSubviews
			for title:String? in titles {
				let label:UILabel! = UILabel()
				label.text = title
				label.textAlignment = .center
				label.adjustsFontSizeToFitWidth = true
				label.minimumScaleFactor = 0.5
				label.lineBreakMode = .byTruncatingTail

				gutter.addSubview(label)
			}
		}
	}
	private var _values:[String]!
	var values:[String]! {
		get { return _values }
		set(values) {
			assert((values.count >= self.titles.count), "Must have as many values as titles.")
			_values = values
		}
	}
	var animated:Bool = true
	private var _selectedIndex:Int = -1
	var selectedIndex:Int {
		get { return _selectedIndex }
		set(selectedIndex) {
			if selectedIndex >= self.titles.count {
				return
			}

			let changed:Bool = (self.selectedIndex != selectedIndex)

			_selectedIndex = selectedIndex
			_selectedValue = self.values[selectedIndex]
			_selectedTitle = self.titles[selectedIndex]

			if changed {
				self.sendActions(for: .valueChanged)
			}

			if self.animated  {
				UIView.animate(withDuration: 0.3,
									delay:0,
									usingSpringWithDamping:0.7,
									initialSpringVelocity:0,
									options: [.beginFromCurrentState, .curveEaseOut],
									animations:{
					self.layoutSubviews()
				},
									completion:nil)
			} else {
				self.layoutSubviews()
			}

		}
	}
	private var _selectedValue:String!
	var selectedValue:String! {
		get { return _selectedValue }
	}
	private var _selectedTitle:String!
	var selectedTitle:String! {
		get { return _selectedTitle }
	}
	var gutterFont:UIFont!
	var gutterTextColor:UIColor!
	private var _gutterBackgroundColor:UIColor!
	var gutterBackgroundColor:UIColor! {
		get {
			return _gutterBackgroundColor
		}
		set(bgcolor) {
			_gutterBackgroundColor = bgcolor

			// update gutter inner shadow color (top inside of gutter) when background color changes
			gutterShadowColor = nil
			var h:CGFloat = 0
			var s:CGFloat = 0
			var b:CGFloat = 0
			var a:CGFloat = 0
			if bgcolor.getHue(&h, saturation:&s, brightness:&b, alpha:&a) {
				gutterShadowColor = UIColor(hue:h, saturation:s, brightness:b * 0.85, alpha:a)
			}
		}
	}
	var handleFont:UIFont!
	var handleTextColor:UIColor!
	private var _handleBackgroundColor:UIColor!
	var handleBackgroundColor:UIColor! {
		get {
			return _handleBackgroundColor
		}
		set(bgcolor) {
			_handleBackgroundColor = bgcolor

			// update handle drop shadow color (bottom outside of handle) when background color changes
			handleShadowColor = nil
			var h:CGFloat = 0
			var s:CGFloat = 0
			var b:CGFloat = 0
			var a:CGFloat = 0
			if bgcolor.getHue(&h, saturation:&s, brightness:&b, alpha:&a) {
				handleShadowColor = UIColor(hue:h, saturation:s, brightness:b * 0.85, alpha:a)
			}
		}
	}
	private var gutter:UIView!
	private var gutterShadow:UIView!
	private var gutterShadowColor:UIColor!
	private var handle:UILabel!
	private var handleShadow:UIView!
	private var handleShadowColor:UIColor!
	private var panStartX:CGFloat = 0

	// MARK: - Initializer

	public required override init(frame: CGRect) {
		super.init(frame: frame)
		self.finishInit()
	}

	required public init?(coder aDecoder: NSCoder) {
		super.init(coder:aDecoder)
		self.finishInit()
	}

	func finishInit() {
		self.backgroundColor = UIColor.clear

		_selectedIndex = 0
		_selectedValue = nil
		_selectedTitle = nil
		self.animated = true

		self.gutterTextColor = UIColor.darkGray
		self.gutterBackgroundColor = UIColor.lightGray

		self.handleTextColor = UIColor.black
		self.handleBackgroundColor = UIColor.white

		gutterShadow = UIView()
		self.addSubview(gutterShadow)

		gutter = UIView()
		self.insertSubview(gutter, aboveSubview:gutterShadow)

		handleShadow = UIView()
		self.insertSubview(handleShadow, aboveSubview:gutter)

		handle = UILabel()
		handle.textAlignment = .center
		handle.adjustsFontSizeToFitWidth = true
		handle.minimumScaleFactor = 0.5
		handle.lineBreakMode = .byTruncatingTail
		handle.clipsToBounds = true
		self.insertSubview(handle, aboveSubview:handleShadow)


		let tap:UITapGestureRecognizer! = UITapGestureRecognizer(target: self, action: #selector(self.tapped(gesture:)))
		self.addGestureRecognizer(tap)

		let pan:UIPanGestureRecognizer! = UIPanGestureRecognizer(target:self, action: #selector(self.panned(gesture:)))
		self.addGestureRecognizer(pan)
	}

	public func gutter(font:UIFont!, color:UIColor!, background bgColor:UIColor!) {
		self.gutterFont = font
		self.gutterTextColor = color
		self.gutterBackgroundColor = bgColor
	}
	public	func handle(font:UIFont!, color:UIColor!, background bgColor:UIColor!) {
		self.handleFont = font
		self.handleTextColor = color
		self.handleBackgroundColor = bgColor
	}


	// MARK: - Selection State Drawing

	open override func layoutSubviews() {
		super.layoutSubviews()

		if self.titles?.count ?? 0 <= 0 {
			print("Nothing to layout because Titles is empty.  Make sure the control is wired up and you call [setTitles:] before this view is expected to appear.")
			return
		}

		// gutter is 60% our height, create its frame moved down inside our size
		let gutterHeight:CGFloat = round(self.bounds.height * 0.60)
		let totalTopBottomMargin:CGFloat = self.bounds.height - gutterHeight
		let gutterFrame:CGRect = CGRect(x:0, y:totalTopBottomMargin / 2.0, width:self.bounds.width, height:gutterHeight)

		// main gutter area
		gutter.frame = gutterFrame.offsetBy(dx: 0, dy: 0)
		gutter.backgroundColor = self.gutterBackgroundColor
		gutter.layer.cornerRadius = gutterHeight / 4.0
		gutter.layer.masksToBounds = true

		// fake inner shadow by starting up 1 from gutter
		gutterShadow.frame = gutterFrame.offsetBy(dx: 0, dy: -1)
		gutterShadow.backgroundColor = gutterShadowColor
		gutterShadow.layer.cornerRadius = gutterHeight / 4.0
		gutterShadow.layer.masksToBounds = true


		// width of each labeled section
		let width:CGFloat = self.bounds.size.width / CGFloat(self.titles.count)

		// labels in gutter - update size, position, and color - text and static details were done in [setTitles:]
		var offset:CGFloat = 0
		for v:UIView? in gutter.subviews {
			if let label:UILabel = v as? UILabel {

				let positionInGutter:CGRect = CGRect(x:(offset * width), y:0, width:width, height:gutter.bounds.size.height)

				label.frame = positionInGutter.insetBy(dx: 4, dy: 2)	// drawing frame inset for visual niceness
				label.textColor = self.gutterTextColor

				// get the default font as late as possible (if needed) after the custom app fonts have had a chance to load; hopefully we get a branded font as the default
				if nil == self.gutterFont {
					self.gutterFont = label.font.withSize(UIFont.smallSystemFontSize)
				}
				label.font = self.gutterFont

				offset = offset + 1
			}
		}


		// move handle over selected item - update backing shadow view position first
		offset = CGFloat(self.selectedIndex)
		handleShadow.frame = CGRect(x:(offset * width), y:0, width:width, height:self.bounds.size.height)
		handleShadow.backgroundColor = handleShadowColor
		handleShadow.layer.cornerRadius = handleShadow.frame.height / 4.0
		handleShadow.layer.masksToBounds = true

		// then update main handle text, colors, and font
		handle.text = self.titles[self.selectedIndex]
		handle.textColor = self.handleTextColor
		handle.backgroundColor = self.handleBackgroundColor
		// get the default font as late as possible (if needed) after the custom app fonts have had a chance to load; hopefully we get a branded font as the default
		if nil == self.handleFont {
			self.handleFont = handle.font.withSize(UIFont.labelFontSize)
		}
		handle.font = self.handleFont
		handle.shadowColor = handleShadowColor

		// draw its frame 2 px shorter so the fake drop shadow view shows at the bottm
		handle.frame = CGRect(x:(offset * width), y:0, width:width, height:self.bounds.size.height - 2.0)

		handle.layer.cornerRadius = handle.frame.height / 4.0
		handle.layer.masksToBounds = true
	}


	// MARK: - Gestures

	@objc func tapped(gesture:UITapGestureRecognizer!) {
		let point:CGPoint = gesture.location(in: self)
		let index:Int = self.indexForPoint(point: point)
		self.selectedIndex = index
	}

	@objc func panned(gesture:UIPanGestureRecognizer!) {
		switch (gesture.state) {

		case .began:
			panStartX = handle.frame.origin.x
			break

		case .changed:

			let offset:CGFloat = gesture.translation(in: self).x
			var x:CGFloat = max(0, panStartX + offset)	// don't go past the left side
			x = min(x, self.bounds.size.width - handle.frame.size.width)	// don't go past the right side;

			var frame:CGRect = handle.frame
			frame.origin.x = x
			handle.frame = frame

			// shadow has same horizontal frame as handle, we can reuse the x for shadow frame
			frame = handleShadow.frame
			frame.origin.x = x
			handleShadow.frame = frame

			// update text while panning
			let index:Int = self.indexForPoint(point: handle.center)
			handle.text = self.titles[index]

			break

		case .ended,
				.failed,
				.cancelled:

			let index:Int = self.indexForPoint(point: handle.center)
			self.selectedIndex = index

			break

		default:
			// nothing to do for 'Possible' and 'Recognized' states
			break
		}
	}

	func indexForPoint(point:CGPoint) -> Int {
		let widthPer:CGFloat = self.bounds.size.width / CGFloat(self.titles.count)
		return Int(floor(point.x / widthPer))
	}
}
