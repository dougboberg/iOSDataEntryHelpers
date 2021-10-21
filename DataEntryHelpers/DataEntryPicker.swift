//
//  DataEntryPicker.swift
//  DataEntryHelpers
//
//  Created by Douglas Boberg
//  Copyright © 2016 Douglas Boberg. All rights reserved.
//
// Rewritten from Objective-C to Swift 5 by Douglas Boberg on October 20, 2021
//

import Foundation
import UIKit


public enum DataEntryPickerType:Int {
	case HumanHeightFT
	case HumanHeightCM
	case PastDate
	case FutureDate
	case AnyDate
	case Generic
}

public protocol DataEntryPickerDelegate : NSObject {
	func beganTextInput()
	func beganShowPicker()
}

open class DataEntryPicker : UIControl, UITextFieldDelegate, UIPickerViewDelegate, UIPickerViewDataSource, UIPopoverPresentationControllerDelegate {


	// MARK: - Setup

	public func setup(dataPickerType:DataEntryPickerType!
							, inputAssistantViewController:UIViewController!
							, nextInputField:UIResponder?
							, delegate:DataEntryPickerDelegate?)
	{
		self.dataPickerType = dataPickerType
		self.inputAssistantViewController = inputAssistantViewController
		self.nextInputField = nextInputField
		self.delegate = delegate
	}

	public var delegate:DataEntryPickerDelegate?
	public var dataPickerType:DataEntryPickerType = .Generic
	public var nextInputField:UIResponder?
	public var inputAssistantViewController:UIViewController?

	public var heightValue:Int! = 0
	public var dateValue:Date! = Date()
	public var genericValues:[String]! = []
	public var genericDefaultValue:String! = ""
	public var genericValue:String! = ""

	public var labelTextColor:UIColor! = UIColor.black
	public var buttonTextColor:UIColor! = UIColor.black
	public var buttonBackgroundColor:UIColor! = UIColor.systemGray2
	public var buttonShadowColor:UIColor! = UIColor.systemGray4
	public var invalidDataIndicatorColor:UIColor! = UIColor.red

	var usePlaceHolderForHeight:Bool = false

	private var _primaryfield:UITextField!
	var primaryfield:UITextField! {
		get { return _primaryfield }
		set { _primaryfield = newValue }
	}

	private var _primarylabel:UILabel!
	var primarylabel:UILabel! {
		get { return _primarylabel }
		set { _primarylabel = newValue }
	}
	private var _secondaryfield:UITextField!
	var secondaryfield:UITextField! {
		get { return _secondaryfield }
		set { _secondaryfield = newValue }
	}
	private var _secondarylabel:UILabel!
	var secondarylabel:UILabel! {
		get { return _secondarylabel }
		set { _secondarylabel = newValue }
	}
	var datefield:UITextField!
	private var _button:UIButton!
	var button:UIButton! {
		get { return _button }
		set { _button = newValue }
	}
	var pickerController:UIViewController!
	var dateformatter:DateFormatter!
	var keyboardAppearance:UIKeyboardAppearance = .default

	// MARK: - Initializer

	public required override init(frame: CGRect) {
		super.init(frame: frame)
		self.finishInit()
	}

	public required init?(coder aDecoder: NSCoder) {
		super.init(coder:aDecoder)
		self.finishInit()
	}

	func finishInit() {
		self.backgroundColor = UIColor.clear
		if self.labelTextColor == nil  {
			self.labelTextColor = UIColor.black
		}

		self.primaryfield = UITextField()
		self.primaryfield.delegate = self
		self.primaryfield.borderStyle = .roundedRect
		self.primaryfield.returnKeyType = .next
		self.primaryfield.autocorrectionType = .no
		self.primaryfield.translatesAutoresizingMaskIntoConstraints = false
		self.primaryfield.keyboardType = .numbersAndPunctuation
		self.primaryfield.keyboardAppearance = self.keyboardAppearance
		self.primaryfield.adjustsFontSizeToFitWidth = true

		self.addSubview(self.primaryfield)

		self.primarylabel = UILabel()
		self.primarylabel.translatesAutoresizingMaskIntoConstraints = false
		self.addSubview(self.primarylabel)

		self.button = UIButton()
		self.button.addTarget(self, action: #selector(showPicker), for: .touchUpInside)
		self.button.titleLabel?.textAlignment = .center
		self.button.titleLabel?.adjustsFontSizeToFitWidth = true
		self.button.titleLabel?.minimumScaleFactor = 0.25
		self.button.setImage(UIImage(systemName: "search"), for: .normal)
		self.button.layer.cornerRadius = 4
		self.button.layer.masksToBounds = false
		self.button.layer.shadowOffset = CGSize(width:0.0,height:2.0)
		self.button.layer.shadowOpacity = 1
		self.button.layer.shadowRadius = 0
		self.button.translatesAutoresizingMaskIntoConstraints = false
		self.addSubview(self.button)

		// Look at this little magical fucker.
		// give the template the pieces you want (month, day, year, hour, minute http://www.unicode.org/reports/tr35/tr35-31/tr35-dates.html#Date_Format_Patterns )
		// and it magically returns them IN ORDER! suitable for the user's locale
		// AND it also includes punctuation!  m/d/yy  it will put in the slashes if that's what is normal in their locale
		// test with locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_GB"];
		let locale:Locale! = Locale.autoupdatingCurrent
		self.dateformatter = DateFormatter()
		self.dateformatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "MMddyy",
																					options:0,
																					locale:locale)


		// Vertical layout - these don't change so set them here
		// FIXME: autolayout
		let viewsDictionary = ["_primaryfield": _primaryfield, "_primarylabel": _primarylabel, "_button": _button, "self": self]
		self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[_primaryfield]|", metrics: nil, views: viewsDictionary))
		self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[_primarylabel]|", metrics: nil, views: viewsDictionary))
		self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[_button]|", metrics: nil, views: viewsDictionary))


		//		let views:NSDictionary! = NSDictionaryOfVariableBindings(_primaryfield, _primarylabel, _button, self)
		//		self.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|[_primaryfield]|",
		//																	 options:0,
		//																	 metrics:nil,
		//																		views:views))
		//		self.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|[_primarylabel]|",
		//																	 options:0,
		//																	 metrics:nil,
		//																		views:views))
		//		self.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|[_button]|",
		//																	 options:0,
		//																	 metrics:nil,
		//																		views:views))


		//debug
//		self.backgroundColor = UIColor.purple.withAlphaComponent(0.3)
//		self.primaryfield.backgroundColor = UIColor.green.withAlphaComponent(0.3)
//		self.primarylabel.backgroundColor = UIColor.yellow.withAlphaComponent(0.5)
//		self.secondaryfield.backgroundColor = UIColor.blue.withAlphaComponent(0.3)
//		self.secondarylabel.backgroundColor = UIColor.orange.withAlphaComponent(0.5)
//		self.button.backgroundColor = UIColor.red.withAlphaComponent(0.1)
	}



	// MARK: - Layout and Display

	open override func updateConstraints() {
		super.updateConstraints()

		switch (self.dataPickerType) {
		case .HumanHeightFT:

			// setup if needed
			if nil == self.secondaryfield {

				self.secondaryfield = UITextField()
				self.secondaryfield.delegate = self
				self.secondaryfield.borderStyle = .roundedRect
				self.secondaryfield.returnKeyType = .next
				self.secondaryfield.keyboardType = .numbersAndPunctuation
				self.secondaryfield.autocorrectionType = .no
				self.secondaryfield.translatesAutoresizingMaskIntoConstraints = false
				self.secondaryfield.backgroundColor = self.primaryfield.backgroundColor
				self.secondaryfield.tintColor = self.primaryfield.tintColor

				self.addSubview(self.secondaryfield)

				self.secondarylabel = UILabel()
				self.secondarylabel.translatesAutoresizingMaskIntoConstraints = false
				self.addSubview(self.secondarylabel)


				// Vertical layout - these don't change so set them once
				let viewsDictionary = ["_secondaryfield": _secondaryfield, "_secondarylabel": _secondarylabel, "self": self]
				self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[_secondaryfield]|", metrics: nil, views: viewsDictionary))
				self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[_secondarylabel]|", metrics: nil, views: viewsDictionary))

				// FIXME: autolayout
				//					let views:NSDictionary! = NSDictionaryOfVariableBindings(_secondaryfield, _secondarylabel, self)
				//					self.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|[_secondaryfield]|",
				//																				 options:0,
				//																				 metrics:nil,
				//																					views:views))
				//					self.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|[_secondarylabel]|",
				//																				 options:0,
				//																				 metrics:nil,
				//																					views:views))
			}

			if  self.usePlaceHolderForHeight  {
				self.primarylabel.text = ""
				self.secondarylabel.text = ""
				self.primarylabel.isHidden = true
				self.secondarylabel.isHidden = true

				self.primaryfield.placeholder = NSLocalizedString("ft", comment:"abbreviation for feet in U.S. customary measuring system")
				self.secondaryfield.placeholder = NSLocalizedString("in", comment:"abbreviation for inches in U.S. customary measuring system")
			} else {
				// layout for FEET type
				self.primarylabel.text = NSLocalizedString("ft", comment:"abbreviation for feet in U.S. customary measuring system")
				self.secondarylabel.text = NSLocalizedString("in", comment:"abbreviation for inches in U.S. customary measuring system")
			}


			// Horizontal layout
			let viewsDictionary = ["_primaryfield": _primaryfield, "_primarylabel": _primarylabel, "_secondaryfield": _secondaryfield, "_secondarylabel": _secondarylabel, "_button": _button, "self": self]
			self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[_primaryfield]-2-[_primarylabel(==24)]-[_secondaryfield(==_primaryfield)]-2-[_secondarylabel(==24)]-2-[_button(==24)]|", metrics: nil, views: viewsDictionary))
			// FIXME: autolayout
			//						  let views:NSDictionary! = NSDictionaryOfVariableBindings(_primaryfield, _primarylabel, _secondaryfield, _secondarylabel, _button, self)
			//
			//						  self.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|[_primaryfield]-2-[_primarylabel(==24)]-[_secondaryfield(==_primaryfield)]-2-[_secondarylabel(==24)]-2-[_button(==24)]|",
			//																											options:0,
			//																											metrics:nil,
			//																											  views:views))

			break

		case .HumanHeightCM:

			// layout for CENTIMETER type
			self.primarylabel.text = NSLocalizedString("cm", comment:"abbreviation for centimeters")

			// Horizontal layout
			let viewsDictionary = ["_primaryfield": _primaryfield, "_primarylabel": _primarylabel, "_button": _button, "self": self]
			self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[_primaryfield]-2-[_primarylabel(==_primaryfield)]-2-[_button(==24)]|", metrics: nil, views: viewsDictionary))
			// FIXME: autolayout
			//				let views:NSDictionary! = NSDictionaryOfVariableBindings(_primaryfield, _primarylabel, _button, self)
			//
			//				self.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|[_primaryfield]-2-[_primarylabel(==_primaryfield)]-2-[_button(==24)]|",
			//																			 options:0,
			//																			 metrics:nil,
			//																				views:views))

			break

		case .Generic:

			self.primarylabel.text = ""

			// Horizontal layout
			let viewsDictionary = ["_primaryfield": _primaryfield, "_button": _button, "self": self]
			self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[_primaryfield]-2-[_button(==24)]|", metrics: nil, views: viewsDictionary))
			// FIXME: autolayout
			//					 let views:NSDictionary! = NSDictionaryOfVariableBindings(_primaryfield, _button, self)
			//					 self.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|[_primaryfield]-2-[_button(==24)]|",
			//																									  options:0,
			//																									  metrics:nil,
			//																										 views:views))

			break

		default:
			// layout for DATE type
			self.primaryfield.placeholder = self.dateformatter.dateFormat

			self.primarylabel.removeFromSuperview()

			// Horizontal layout
			let viewsDictionary = ["_primaryfield": _primaryfield, "_button": _button, "self": self]
			self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[_primaryfield]-2-[_button(==24)]|", metrics: nil, views: viewsDictionary))
			// FIXME: autolayout
			//				let views:NSDictionary! = NSDictionaryOfVariableBindings(_primaryfield, _button, self)
			//
			//				self.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|[_primaryfield]-2-[_button(==24)]|",
			//																			 options:0,
			//																			 metrics:nil,
			//																				views:views))

			break
		}

		self.button.setTitleColor(self.buttonTextColor, for:.normal)
		self.button.backgroundColor = self.buttonBackgroundColor
		self.button.layer.shadowColor = self.buttonShadowColor.cgColor

		self.primarylabel.textColor = self.labelTextColor
		self.primaryfield.keyboardAppearance = self.keyboardAppearance

		self.secondarylabel.textColor = self.labelTextColor


	}

	open override func layoutSubviews() {
		super.layoutSubviews()
		self.updateFieldDisplay()
	}

	func updateFieldDisplay() {
		switch (self.dataPickerType) {
		case .HumanHeightFT:

			let feet:Int = self.heightValue ?? 0 / 12
			if feet > 0 {
				self.primaryfield.text = String(format:"%d", feet)
			} else {
				self.primaryfield.text = ""
			}

			let inches:Int = self.heightValue ?? 0 % 12
			if inches > 0 {
				self.secondaryfield.text = String(format:"%d", inches)
			} else {
				self.secondaryfield.text = ""
			}

			break

		case .HumanHeightCM:
			if self.heightValue ?? 0 > 0 {
				self.primaryfield.text = String(format:"%d", self.heightValue ?? 0)
			} else {
				self.primaryfield.text = ""
			}
			break

		case .Generic:
			if let generic:String = self.genericValue {
				self.primaryfield.text = generic
			} else {
				self.primaryfield.text = ""
			}
			break

		default:
			if let date:Date = self.dateValue {
				self.primaryfield.text = self.dateformatter.string(from: date)
			} else {
				self.primaryfield.text = ""
			}
			break
		}

	}


	// MARK: - Responder Sequence

	open override func resignFirstResponder() -> Bool {
		self.primaryfield.resignFirstResponder()
		self.secondaryfield.resignFirstResponder()
		self.pickerController.dismiss(animated: false, completion:nil)
		return super.resignFirstResponder()
	}

	open override func becomeFirstResponder() -> Bool {
		self.primaryfield.becomeFirstResponder()
		return super.becomeFirstResponder()
	}

	// MARK: - Text Field entry
	public func textFieldShouldBeginEditing(_ textField:UITextField) -> Bool {
		self.delegate?.beganTextInput()

		//		  // if the button is hidden, we only allow picker input (no keyboard)
		//		  if self.button.hidden {
		//
		//				// hide the keyboard on the parent view controller, then show the picker
		//				if self.inputAssistantViewController != nil  {
		//					 self.inputAssistantViewController.view.endEditing(true)
		//				}
		//
		//				self.showPicker()
		//
		//				// return false to prevent default keyboard from showing
		//				return false
		//		  }
		self.showPicker()
		// if we have the button, we return true to allow Keyboard entry. Picker input is done with the button (elsewhere in this code)
		return true
	}

	public func textFieldShouldReturn(_ textField:UITextField) -> Bool {
		if textField == self.primaryfield && nil != self.secondaryfield {
			self.secondaryfield.becomeFirstResponder()
		} else {
			if self.dataPickerType == .HumanHeightFT  {
				let feet:Int = Int(self.primaryfield.text ?? "0") ?? 0
				let inches:Int = Int(self.secondaryfield.text ?? "0") ?? 0
				self.heightValue = Int(((feet * 12) + inches))

			} else if self.dataPickerType == .HumanHeightCM  {
				self.heightValue = Int(self.primaryfield.text ?? "0") ?? 0

			}

			// FIXME: NSNotificationCenter.defaultCenter().postNotificationName(kDataEntryPickerReturnNotification, object: self)

			self.nextInputField?.becomeFirstResponder()
		}

		self.updateFieldDisplay()

		return false
	}

	public func textFieldDidEndEditing(_ textField:UITextField) {
		switch (self.dataPickerType) {
		case .HumanHeightFT:

			let feet:Int = Int(self.primaryfield.text ?? "0") ?? 0
			let inches:Int = Int(self.secondaryfield.text ?? "0") ?? 0
			self.heightValue = Int(((feet * 12) + inches))

			break

		case .HumanHeightCM:
			self.heightValue = Int(self.primaryfield.text ?? "0") ?? 0
			break

		case .Generic:
			self.genericValue = self.primaryfield.text
			break

		default:
			self.dateValue = self.dateformatter.date(from: self.primaryfield.text ?? "")
			break
		}

		// data has changed:  alert & update display
		self.sendActions(for: .valueChanged)

		self.updateFieldDisplay()

	}


	// MARK: - Picker presentation

	@objc func showPicker() {
		self.delegate?.beganShowPicker()

		self.primaryfield.resignFirstResponder()
		self.secondaryfield.resignFirstResponder()
		self.primaryfield.layer.borderWidth = 0.0
		self.secondaryfield.layer.borderWidth = 0.0

		self.pickerController = UIViewController()

		var picker:UIPickerView!
		var datepicker:UIDatePicker!

		if self.dataPickerType == .HumanHeightFT || self.dataPickerType == .HumanHeightCM {
			picker = UIPickerView()
			picker.dataSource = self
			picker.delegate = self

			self.pickerController.view = picker
			self.pickerController.preferredContentSize = picker.sizeThatFits(CGSize())

		} else if  self.dataPickerType == .Generic {
			picker = UIPickerView()
			picker.dataSource = self
			picker.delegate = self

			self.pickerController.view = picker
			self.pickerController.preferredContentSize = picker.sizeThatFits(CGSize())
		} else {
			datepicker = UIDatePicker()
			datepicker.datePickerMode = .date
			datepicker.preferredDatePickerStyle = .wheels

			datepicker.addTarget(self, action:#selector(datePickerValueChanged(datepicker:)), for:.valueChanged)

			if self.dataPickerType == .FutureDate  {
				datepicker.minimumDate = Date()
			} else if self.dataPickerType == .PastDate {
				datepicker.maximumDate = Date()
			}

			self.pickerController.view = datepicker
			self.pickerController.preferredContentSize = datepicker.sizeThatFits(CGSize())
		}

		self.pickerController.modalPresentationStyle = .popover
		self.pickerController.popoverPresentationController?.sourceView = self.primaryfield
		self.pickerController.popoverPresentationController?.sourceRect = self.primaryfield.bounds
		self.pickerController.popoverPresentationController?.canOverlapSourceViewRect = false
		self.pickerController.popoverPresentationController?.backgroundColor = UIColor.white
		self.pickerController.popoverPresentationController?.delegate = self


		guard let assistantVC:UIViewController = self.inputAssistantViewController else {
			print("Cannot show picker! Please assign an input Assistant ViewController")
			return
		}

		assistantVC.present(self.pickerController, animated:true, completion:{

			// select the current value, or a default value for each type

			switch (self.dataPickerType) {
			case .HumanHeightFT:
				if let height:Int = self.heightValue {
					picker.selectRow((height  / 12), inComponent: 0, animated: true)
					picker.selectRow((height  % 12), inComponent: 1, animated: true)
				} else {
					picker.selectRow(5, inComponent: 0, animated: true)
					picker.selectRow(10, inComponent: 1, animated: true)
					//we want to set this as default value so if they dismiss we still have the value
					self.heightValue = Int(70)
				}
				break

			case .HumanHeightCM:
				if let height:Int = self.heightValue {
					picker.selectRow((height / 100), inComponent: 0, animated: true)
					picker.selectRow((height % 100), inComponent: 1, animated: true)
				} else {
					picker.selectRow(1, inComponent: 0, animated: true)
					picker.selectRow(60, inComponent: 1, animated: true)
				}
				break

			case .PastDate:
				if let date:Date = self.dateValue {
					datepicker.setDate(date, animated:true)
				} else {
					datepicker.setDate(Date.init(timeIntervalSinceNow: -32000000), animated:true) // last year-ish
				}
				break

			case .AnyDate:
				if let date:Date = self.dateValue {
					datepicker.setDate(date, animated:true)
				} else {
					datepicker.setDate(Date.init(timeIntervalSinceNow: 0), animated:true) // now
				}
				break

			case .FutureDate:
				if let date:Date = self.dateValue {
					datepicker.setDate(date, animated:true)
				} else {
					datepicker.setDate(Date.init(timeIntervalSinceNow: 32000000), animated:true) // next year-ish
				}
				break

			case .Generic:
				if let generic:String = self.genericValue {
					if let values = self.genericValues {
						picker.selectRow( (values.firstIndex(of:generic) ?? 0), inComponent:0, animated: true)
					}
				}
				break

				//			case .none:
				//				print("DataEntryPicker: dataPickerType not set. nothing to do.")
				//				break
			}

			DispatchQueue.main.async {
				self.updateFieldDisplay()
			}
		})


	}

	// magic to make pop-overs work on iPhone
	func adaptivePresentationStyleForPresentationController(controller:UIPresentationController!) -> UIModalPresentationStyle {
		return .none
	}


	// MARK: - Picker data

	public func numberOfComponents(in pickerView: UIPickerView) -> Int {
		switch (self.dataPickerType) {
		case .Generic:
			return 1
		case .HumanHeightFT,
				.HumanHeightCM:
			return 2

		default:
			return 3
		}
	}


	public func pickerView(_ pickerView:UIPickerView, numberOfRowsInComponent component:Int) -> Int {
		switch (self.dataPickerType) {
		case .HumanHeightFT:
			return (component == 0) ? 9 : 12	//0-8 ft, 0-11 in


		case .HumanHeightCM:
			return (component == 0) ? 3 : 100	//0-2 m, 0-99 cm


		case .Generic:
			if let values = self.genericValues {
				return values.count
			}
			return 0



		default:
			return 3

		}
	}

	public func pickerView(_ pickerView:UIPickerView, titleForRow row:Int, forComponent component:Int) -> String? {
		switch (self.dataPickerType) {
		case .HumanHeightFT:
			return (component == 0) ? String(format:"%d ft", row) : String(format:"%d in", row)


		case .HumanHeightCM:
			return (component == 0) ? String(format:"%d", row) : String(format:"%d cm", row)


		case .Generic:
			if let values = self.genericValues {
				return values[row]
			}
			return ""


		default:
			return ""

		}
	}


	public func pickerView(_ pickerView:UIPickerView, didSelectRow row:Int, inComponent component:Int) {
		switch (self.dataPickerType) {
		case .HumanHeightFT:

			let feet:Int = pickerView.selectedRow(inComponent: 0)
			let inches:Int = pickerView.selectedRow(inComponent: 1)
			self.heightValue = Int(((feet * 12) + inches))


			break

		case .HumanHeightCM:

			let m:Int = pickerView.selectedRow(inComponent: 0)
			let cm:Int = pickerView.selectedRow(inComponent: 1)
			self.heightValue = Int(((m * 100) + cm))

			break

		case .Generic:
			if let values = self.genericValues {
				self.genericValue = values[row]
			}

			break

		default:
			break
		}

		// data has changed:  alert & update display
		self.sendActions(for: .valueChanged)

		self.updateFieldDisplay()
	}


	// MARK: - Date Picker data
	@objc func datePickerValueChanged(datepicker:UIDatePicker!) {
		self.dateValue = datepicker.date

		// data has changed:  alert & update display
		self.sendActions(for: .valueChanged)

		self.updateFieldDisplay()
	}


	// MARK: - Data Validation

	func indicateInvalidData() {
		// should we pass in a boolean to turn this On/Off so we don't rely on the internal isValidData call?
		// what if we want to do validation outside of PCI rules?

		self.primaryfield.layer.borderColor = self.invalidDataIndicatorColor.cgColor
		self.secondaryfield.layer.borderColor = self.invalidDataIndicatorColor.cgColor

		if !self.isValidData() {
			self.primaryfield.layer.borderWidth = 1.5
			self.primaryfield.layer.cornerRadius = 4.0
			self.secondaryfield.layer.borderWidth = 1.5
			self.secondaryfield.layer.cornerRadius = 4.0
		} else {
			self.primaryfield.layer.borderWidth = 0.0
			self.secondaryfield.layer.borderWidth = 0.0
		}
	}

	func clearInvalidData() {
		self.primaryfield.layer.borderWidth = 0.0
		self.secondaryfield.layer.borderWidth = 0.0
	}

	func isValidData() -> Bool {
		self.endEditing(true)	// this forces parsing of the data entry fields

		switch (self.dataPickerType) {
		case .HumanHeightFT:
			// valid if greater than 10 inches
			return (self.heightValue ?? 0  > 10)

		case .HumanHeightCM:
			// valid if greater than 10 cm
			return (self.heightValue ?? 0  > 10)

		case .PastDate:
			// valid if date is less than now (in the past)
			if let date:Date = self.dateValue {
				return (date.timeIntervalSinceNow < 0)
			}
			return false;



		case .AnyDate:
			// valid if a date object
			return (self.dateValue != nil)


		case .FutureDate:
			// valid if date is greater than now (in the future)
			if let date:Date = self.dateValue {
				return (date.timeIntervalSinceNow > 0)
			}
			return false;


		case .Generic:
			return (self.genericValue != nil)

			//		case .none:
			//			print("DataEntryPicker: dataPickerType not set. nothing to validate.")
		}

		// if there is no requirement for a specific data above, then gigo freeform I guess you're good.
		return true
	}

	func clearData() {
		self.dateValue = nil
		self.genericValue = nil

		self.primaryfield.text = ""

		if  (self.secondaryfield != nil)  {
			self.secondaryfield.text = ""
		}

		self.primaryfield.layer.borderWidth = 0.0
		self.secondaryfield.layer.borderWidth = 0.0

		self.updateConstraints()
	}
}
