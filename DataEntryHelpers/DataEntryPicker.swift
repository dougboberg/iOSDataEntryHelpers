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
	case HumanHeightIN
	case HumanHeightCM
	case HumanWeightLB
	case HumanWeightKG
	case PastDate
	case FutureDate
	case AnyDate
	case MultiArray
}

public protocol DataEntryPickerDelegate : NSObject {
	func beganTextInput(control:DataEntryPicker)
	func beganShowPicker(control:DataEntryPicker)
	func valueChanged(control:DataEntryPicker)
}

open class DataEntryPicker : UIControl, UITextFieldDelegate, UIPickerViewDelegate, UIPickerViewDataSource, UIPopoverPresentationControllerDelegate {

	// picker and delegate behavior
	public var delegate:DataEntryPickerDelegate?
	public var dataPickerType:DataEntryPickerType = .AnyDate
	public var nextInputField:UIResponder?
	public var inputAssistantViewController:UIViewController?
	public var animatePickerSelection:Bool = true

	// keyboard behavior
	public var showKeyboard:Bool = false
	public var keyboardAppearance:UIKeyboardAppearance = .default
	public var keyboardType:UIKeyboardType = .numbersAndPunctuation

	// component column setup for Generic type (dates are automatic, height & weight are hardcoded)
	public var multiArrayColumns:[[String]]? = []
	let multiArrayDisplaySeparator = ","

	// resulting user-picked values
	public var heightValue:Int? = 0
	public var weightValue:Int? = 0
	public var dateValue:Date?
	public var multiArrayValue:[String]?

	// design
	public var labelTextColor:UIColor! = UIColor.black
	public var buttonIcon:UIImage?
	public var buttonTextColor:UIColor! = UIColor.black
	public var buttonBackgroundColor:UIColor! = UIColor.systemGray2
	public var buttonShadowColor:UIColor! = UIColor.systemGray4
	public var invalidDataIndicatorColor:UIColor! = UIColor.red


	// internals
	private var _primaryfield:UITextField! = UITextField()
	private var _primarylabel:UILabel! = UILabel()
	private var _secondaryfield:UITextField?
	private var _secondarylabel:UILabel?
	private var _button:UIButton?
	private var _picker:UIPickerView! = UIPickerView()
	private var _datePicker:UIDatePicker! = UIDatePicker()
	private var _pickerController:UIViewController! = UIViewController()
	private var _dateFormatter:DateFormatter! = DateFormatter()

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
		_primaryfield.delegate = self
		_primaryfield.borderStyle = .roundedRect
		_primaryfield.returnKeyType = .next
		_primaryfield.autocorrectionType = .no
		_primaryfield.translatesAutoresizingMaskIntoConstraints = false
		_primaryfield.keyboardType = self.keyboardType
		_primaryfield.keyboardAppearance = self.keyboardAppearance
		_primaryfield.adjustsFontSizeToFitWidth = true

		self.addSubview(_primaryfield)

		_primarylabel.translatesAutoresizingMaskIntoConstraints = false
		self.addSubview(_primarylabel)

		if let icon = self.buttonIcon {
			_button = UIButton()
			if let button = _button {
				button.addTarget(self, action: #selector(showPicker), for: .touchUpInside)
				button.titleLabel?.textAlignment = .center
				button.titleLabel?.adjustsFontSizeToFitWidth = true
				button.titleLabel?.minimumScaleFactor = 0.25
				button.setImage(icon, for: .normal)
				button.layer.cornerRadius = 4
				button.layer.masksToBounds = false
				button.layer.shadowOffset = CGSize(width:0.0,height:2.0)
				button.layer.shadowOpacity = 1
				button.layer.shadowRadius = 0
				button.translatesAutoresizingMaskIntoConstraints = false
				self.addSubview(button)
			}
		}

		// Look at this little magical fucker.
		// give the template the pieces you want (month, day, year, hour, minute http://www.unicode.org/reports/tr35/tr35-31/tr35-dates.html#Date_Format_Patterns )
		// and it magically returns them IN ORDER! suitable for the user's locale
		// AND it also includes punctuation!  m/d/yy  it will put in the slashes if that's what is normal in their locale
		// test with locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_GB"];
		let locale:Locale! = Locale.autoupdatingCurrent
		_dateFormatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "MMddyy",
																			  options:0,
																			  locale:locale)


		// Vertical layout - these don't change so set them here
		var viewsDictionary:[String:Any] = ["_primaryfield": _primaryfield, "_primarylabel": _primarylabel, "self": self]
		self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[_primaryfield]|", metrics: nil, views: viewsDictionary))
		self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[_primarylabel]|", metrics: nil, views: viewsDictionary))
		if let button:UIButton = _button {
			viewsDictionary["button"] = button
			self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[button]|", metrics: nil, views: viewsDictionary))
		}


		//debug
		//		self.backgroundColor = UIColor.purple.withAlphaComponent(0.3)
		//		_primaryfield.backgroundColor = UIColor.green.withAlphaComponent(0.3)
		//		_primarylabel.backgroundColor = UIColor.yellow.withAlphaComponent(0.5)
		//		_secondaryfield.backgroundColor = UIColor.blue.withAlphaComponent(0.3)
		//		_secondarylabel.backgroundColor = UIColor.orange.withAlphaComponent(0.5)
		//		_button.backgroundColor = UIColor.red.withAlphaComponent(0.1)
	}



	// MARK: - Layout and Display

	open override func updateConstraints() {
		super.updateConstraints()

		if let button = _button {
			button.setTitleColor(self.buttonTextColor, for:.normal)
			button.backgroundColor = self.buttonBackgroundColor
			button.layer.shadowColor = self.buttonShadowColor.cgColor
		}

		_primaryfield.keyboardAppearance = self.keyboardAppearance
		_primarylabel.textColor = self.labelTextColor

		switch (self.dataPickerType) {
		case .HumanHeightIN:

			// layout for INCHES type
			_primarylabel.text = NSLocalizedString("ft", comment:"abbreviation for feet in U.S. customary measuring system")

			if _secondaryfield == nil {
				_secondaryfield = UITextField()
			}
			if _secondarylabel == nil {
				_secondarylabel = UILabel()
			}

			if let field = _secondaryfield {
				field.delegate = self
				field.borderStyle = .roundedRect
				field.returnKeyType = .next
				field.keyboardType = self.keyboardType
				field.keyboardAppearance = self.keyboardAppearance
				field.autocorrectionType = .no
				field.translatesAutoresizingMaskIntoConstraints = false
				field.backgroundColor = _primaryfield.backgroundColor
				field.tintColor = _primaryfield.tintColor
				self.addSubview(field)
			}


			if let label = _secondarylabel {
				label.text = NSLocalizedString("in", comment:"abbreviation for inches in U.S. customary measuring system")
				label.translatesAutoresizingMaskIntoConstraints = false
				label.textColor = self.labelTextColor
				self.addSubview(label)
			}


			// Vertical layout - these don't change so set them once
			let viewsDictionary:[String:Any] = ["_secondaryfield": _secondaryfield!, "_secondarylabel": _secondarylabel!, "self": self]
			self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[_secondaryfield]|", metrics: nil, views: viewsDictionary))
			self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[_secondarylabel]|", metrics: nil, views: viewsDictionary))


			// Horizontal layout
			if _button != nil {
				let viewsDictionary:[String:Any] = ["_primaryfield": _primaryfield, "_primarylabel": _primarylabel, "_secondaryfield": _secondaryfield!, "_secondarylabel": _secondarylabel!, "_button": _button!, "self": self]
				self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[_primaryfield]-2-[_primarylabel(==24)]-[_secondaryfield(==_primaryfield)]-2-[_secondarylabel(==24)]-2-[_button(==24)]|", metrics: nil, views: viewsDictionary))
			} else {
				let viewsDictionary:[String:Any] = ["_primaryfield": _primaryfield, "_primarylabel": _primarylabel, "_secondaryfield": _secondaryfield!, "_secondarylabel": _secondarylabel!, "self": self]
				self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[_primaryfield]-2-[_primarylabel(==24)]-[_secondaryfield(==_primaryfield)]-2-[_secondarylabel(==24)]|", metrics: nil, views: viewsDictionary))
			}
			break

		case .HumanHeightCM:

			// layout for CENTIMETER type
			_primarylabel.text = NSLocalizedString("cm", comment:"abbreviation for centimeters")

			// Horizontal layout
			if _button != nil {
				let viewsDictionary:[String:Any] = ["_primaryfield": _primaryfield, "_primarylabel": _primarylabel, "_button": _button!, "self": self]
				self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[_primaryfield]-2-[_primarylabel(==_primaryfield)]-2-[_button(==24)]|", metrics: nil, views: viewsDictionary))
			} else {
				let viewsDictionary:[String:Any] = ["_primaryfield": _primaryfield, "_primarylabel": _primarylabel, "self": self]
				self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[_primaryfield]-2-[_primarylabel(==_primaryfield)]|", metrics: nil, views: viewsDictionary))
			}
			break

		case .HumanWeightLB:

			// layout for POUNDS type
			_primarylabel.text = NSLocalizedString("lb", comment:"abbreviation for pound weight")

			// Horizontal layout
			if _button != nil {
				let viewsDictionary:[String:Any] = ["_primaryfield": _primaryfield, "_primarylabel": _primarylabel, "_button": _button!, "self": self]
				self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[_primaryfield]-2-[_primarylabel(==_primaryfield)]-2-[_button(==24)]|", metrics: nil, views: viewsDictionary))
			} else {
				let viewsDictionary:[String:Any] = ["_primaryfield": _primaryfield, "_primarylabel": _primarylabel, "self": self]
				self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[_primaryfield]-2-[_primarylabel(==_primaryfield)]|", metrics: nil, views: viewsDictionary))
			}
			break

		case .HumanWeightKG:

			// layout for KILOGRAM type
			_primarylabel.text = NSLocalizedString("kg", comment:"abbreviation for kilogram weight")

			// Horizontal layout
			if _button != nil {
				let viewsDictionary:[String:Any] = ["_primaryfield": _primaryfield, "_primarylabel": _primarylabel, "_button": _button!, "self": self]
				self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[_primaryfield]-2-[_primarylabel(==_primaryfield)]-2-[_button(==24)]|", metrics: nil, views: viewsDictionary))
			} else {
				let viewsDictionary:[String:Any] = ["_primaryfield": _primaryfield, "_primarylabel": _primarylabel, "self": self]
				self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[_primaryfield]-2-[_primarylabel(==_primaryfield)]|", metrics: nil, views: viewsDictionary))
			}
			break

		case .MultiArray:

			_primarylabel.text = ""

			// Horizontal layout
			if _button != nil {
				let viewsDictionary:[String:Any] = ["_primaryfield": _primaryfield, "_button": _button!, "self": self]
				self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[_primaryfield]-2-[_button(==24)]|", metrics: nil, views: viewsDictionary))
			} else {
				let viewsDictionary:[String:Any] = ["_primaryfield": _primaryfield, "self": self]
				self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[_primaryfield]|", metrics: nil, views: viewsDictionary))
			}
			break

		default:
			// layout for DATE type
			_primaryfield.placeholder = _dateFormatter.dateFormat

			_primarylabel.removeFromSuperview()

			// Horizontal layout
			if _button != nil {
				let viewsDictionary:[String:Any] = ["_primaryfield": _primaryfield, "_button": _button!, "self": self]
				self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[_primaryfield]-2-[_button(==24)]|", metrics: nil, views: viewsDictionary))
			} else {
				let viewsDictionary:[String:Any] = ["_primaryfield": _primaryfield, "self": self]
				self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[_primaryfield]|", metrics: nil, views: viewsDictionary))
			}
			break
		}

	}

	open override func layoutSubviews() {
		super.layoutSubviews()
		self.updateFieldDisplay()
	}

	func updateFieldDisplay() {
		switch (self.dataPickerType) {
		case .HumanHeightIN:

			let feet:Int = (self.heightValue ?? 0) / 12
			let inches:Int = (self.heightValue ?? 0) % 12

			if feet > 0 {
				_primaryfield.text = String(format:"%d", feet)
			} else {
				_primaryfield.text = ""
			}
			if inches > 0 {
				_secondaryfield?.text = String(format:"%d", inches)
			} else {
				_secondaryfield?.text = ""
			}

			break

		case .HumanHeightCM:
			if let height:Int = self.heightValue, (self.heightValue ?? 0) > 0 {
				_primaryfield.text = String(format:"%d", height)
			} else {
				_primaryfield.text = ""
			}
			break

		case .HumanWeightLB, .HumanWeightKG:
			if let weight:Int = self.weightValue, (self.weightValue ?? 0) > 0 {
				_primaryfield.text = String(format:"%d", weight)
			} else {
				_primaryfield.text = ""
			}
			break

		case .MultiArray:
			if let multi = self.multiArrayValue {
				_primaryfield.text = multi.joined(separator: "\(multiArrayDisplaySeparator) ")
			} else {
				_primaryfield.text = ""
			}
			break

		default:
			if let date:Date = self.dateValue {
				_primaryfield.text = _dateFormatter.string(from: date)
			} else {
				_primaryfield.text = ""
			}
			break
		}

	}


	// MARK: - Responder Sequence

	open override func resignFirstResponder() -> Bool {
		_primaryfield.resignFirstResponder()
		_secondaryfield?.resignFirstResponder()
		_pickerController.dismiss(animated: false, completion:nil)
		return super.resignFirstResponder()
	}

	open override func becomeFirstResponder() -> Bool {
		_primaryfield.becomeFirstResponder()
		return super.becomeFirstResponder()
	}

	// MARK: - Text Field entry
	public func textFieldShouldBeginEditing(_ textField:UITextField) -> Bool {
		self.delegate?.beganTextInput(control: self)

		// only allow picker input (no keyboard)
		if showKeyboard {
			// show the picker and return true to get they default keyboard
			self.showPicker()
			return true
		}

		// else hide the keyboard on the parent view controller, then show the picker
		self.inputAssistantViewController?.view.endEditing(true)
		self.showPicker()
		// return false to prevent default keyboard from showing
		return false
	}

	public func textFieldShouldReturn(_ textField:UITextField) -> Bool {
		_pickerController.dismiss(animated: false, completion:nil)
		_primaryfield.resignFirstResponder()

		if textField == _primaryfield && nil != _secondaryfield {
			// need to collect data from second field
			_secondaryfield?.becomeFirstResponder()

		} else {
			// all fields completed, parse the values
			if self.dataPickerType == .HumanHeightIN  {
				let feet:Int = Int(_primaryfield.text ?? "0") ?? 0
				let inches:Int = Int(_secondaryfield?.text ?? "0") ?? 0
				self.heightValue = Int(((feet * 12) + inches))

			} else if self.dataPickerType == .HumanHeightCM  {
				self.heightValue = Int(_primaryfield.text ?? "0") ?? 0

			} else if self.dataPickerType == .HumanWeightLB ||  self.dataPickerType == .HumanWeightKG  {
				self.weightValue = Int(_primaryfield.text ?? "0") ?? 0
			}

			_secondaryfield?.resignFirstResponder()
			self.nextInputField?.becomeFirstResponder()
		}

		self.updateFieldDisplay()

		return false
	}

	public func textFieldDidEndEditing(_ textField:UITextField) {
		_pickerController.dismiss(animated: false, completion:nil)
		_primaryfield.resignFirstResponder()
		_secondaryfield?.resignFirstResponder()

		switch (self.dataPickerType) {
		case .HumanHeightIN:

			let feet:Int = Int(_primaryfield.text ?? "0") ?? 0
			let inches:Int = Int(_secondaryfield?.text ?? "0") ?? 0
			self.heightValue = Int(((feet * 12) + inches))

			break

		case .HumanHeightCM:
			self.heightValue = Int(_primaryfield.text ?? "0") ?? 0
			break

		case .HumanWeightLB, .HumanWeightKG:
			self.weightValue = Int(_primaryfield.text ?? "0") ?? 0
			break

		case .MultiArray:
			if let splitText = _primaryfield.text?.split(separator: Character(multiArrayDisplaySeparator)) {
				var selected:[String] = []
				if splitText.count > 0 {
					for pos in 0...(splitText.count - 1) {
						selected.append(String(splitText[pos]).trimmingCharacters(in: .whitespacesAndNewlines))
					}
				}
				self.multiArrayValue = selected
			}
			break

		default:
			self.dateValue = _dateFormatter.date(from: _primaryfield.text ?? "")
			break
		}

		// Text Field did End: data has changed, alert & update display
		self.sendActions(for: .valueChanged)
		self.delegate?.valueChanged(control: self)

		self.updateFieldDisplay()

	}

	public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {

		// when entering weight we scroll to the typed value
		if self.dataPickerType == .HumanWeightLB || self.dataPickerType == .HumanWeightKG  {

			if let input:String = textField.text, let inputRange:Range = Range(range, in: input) {
				let newValue:String = input.replacingCharacters(in: inputRange, with: string)
				let row:Int = min(Int(newValue) ?? 0, _picker.numberOfRows(inComponent: 0) - 1)
				_picker.selectRow(row, inComponent: 0, animated: self.animatePickerSelection)
			}
		}

		return true
	}


	// MARK: - Picker presentation

	@objc func showPicker() {
		guard let assistantVC:UIViewController = self.inputAssistantViewController else {
			print("Cannot show picker! Please assign an input Assistant ViewController")
			return
		}


		self.delegate?.beganShowPicker(control: self)

		_primaryfield.resignFirstResponder()
		_secondaryfield?.resignFirstResponder()
		_primaryfield.layer.borderWidth = 0.0
		_secondaryfield?.layer.borderWidth = 0.0

		if self.dataPickerType == .HumanHeightIN
				|| self.dataPickerType == .HumanHeightCM
				|| self.dataPickerType == .HumanWeightLB
				|| self.dataPickerType == .HumanWeightKG
				|| self.dataPickerType == .MultiArray  {
			_picker.dataSource = self
			_picker.delegate = self

			_pickerController.view = _picker
			_pickerController.preferredContentSize = _picker.sizeThatFits(CGSize())

		} else {
			_datePicker.datePickerMode = .date
			_datePicker.preferredDatePickerStyle = .wheels

			//			_datePicker.addTarget(self, action:#selector(datePickerValueChanged()), for:.valueChanged)

			if self.dataPickerType == .FutureDate  {
				_datePicker.minimumDate = Date()
			} else if self.dataPickerType == .PastDate {
				_datePicker.maximumDate = Date()
			}

			_pickerController.view = _datePicker
			_pickerController.preferredContentSize = _datePicker.sizeThatFits(CGSize())
		}

		_pickerController.modalPresentationStyle = .popover
		_pickerController.popoverPresentationController?.sourceView = _primaryfield
		_pickerController.popoverPresentationController?.sourceRect = _primaryfield.bounds
		_pickerController.popoverPresentationController?.canOverlapSourceViewRect = false
		_pickerController.popoverPresentationController?.backgroundColor = UIColor.white
		_pickerController.popoverPresentationController?.delegate = self


		if animatePickerSelection {
			// animate the selections, set them in the completion after present()
			assistantVC.present(_pickerController, animated:true, completion:{
				self.selectValueOrDefault()
			})

		} else {
			// don't animate the selections, set them befor calling present()
			self.selectValueOrDefault()
			assistantVC.present(_pickerController, animated:true, completion:nil)
		}



	}

	func selectValueOrDefault() {

		// select the current value, or a default value for each type

		switch (self.dataPickerType) {
		case .HumanHeightIN:
			if let height:Int = self.heightValue {
				_picker.selectRow((height  / 12), inComponent: 0, animated: self.animatePickerSelection)
				_picker.selectRow((height  % 12), inComponent: 1, animated: self.animatePickerSelection)
			} else {
				_picker.selectRow(5, inComponent: 0, animated: self.animatePickerSelection)
				_picker.selectRow(10, inComponent: 1, animated: self.animatePickerSelection)
				//we want to set this as default value so if they dismiss we still have the value
				self.heightValue = Int(70)
			}
			break

		case .HumanHeightCM:
			if let height:Int = self.heightValue {
				_picker.selectRow((height / 100), inComponent: 0, animated: self.animatePickerSelection)
				_picker.selectRow((height % 100), inComponent: 1, animated: self.animatePickerSelection)
			} else {
				_picker.selectRow(1, inComponent: 0, animated: self.animatePickerSelection)
				_picker.selectRow(60, inComponent: 1, animated: self.animatePickerSelection)
			}
			break

		case .HumanWeightLB:
			if let weight:Int = self.weightValue {
				_picker.selectRow(weight, inComponent: 0, animated: self.animatePickerSelection)
			} else {
				_picker.selectRow(100, inComponent: 0, animated: self.animatePickerSelection)
			}
			break

		case .HumanWeightKG:
			if let weight:Int = self.weightValue {
				_picker.selectRow(weight, inComponent: 0, animated: self.animatePickerSelection)
			} else {
				_picker.selectRow(45, inComponent: 0, animated: self.animatePickerSelection)
			}
			break

		case .PastDate:
			if let date:Date = self.dateValue {
				_datePicker.setDate(date, animated:true)
			} else {
				_datePicker.setDate(Date.init(timeIntervalSinceNow: -32000000), animated:self.animatePickerSelection) // before last year-ish
			}
			break

		case .AnyDate:
			if let date:Date = self.dateValue {
				_datePicker.setDate(date, animated:true)
			} else {
				_datePicker.setDate(Date.init(timeIntervalSinceNow: 0), animated:self.animatePickerSelection) // now
			}
			break

		case .FutureDate:
			if let date:Date = self.dateValue {
				_datePicker.setDate(date, animated:true)
			} else {
				_datePicker.setDate(Date.init(timeIntervalSinceNow: 32000000), animated:self.animatePickerSelection) // after next year-ish
			}
			break

		case .MultiArray:
			if let multi:[String] = self.multiArrayValue, let columns:[[String]] = self.multiArrayColumns {
				if multi.count != columns.count {
					self.multiArrayValue = self.makeMultiValueDefault()
				}

				for col in 0...(columns.count - 1) {
					let rows:[String] = columns[col]
					for row in 0...(rows.count - 1) {
						if col < multi.count && multi[col] == rows[row] {
							_picker.selectRow(row, inComponent: col, animated: true)
							break
						}
					}
				}

			} else {
				self.multiArrayValue = self.makeMultiValueDefault()
			}
			break
		}

		DispatchQueue.main.async {
			// default Picker values selected: data has changed, alert & update display
			self.sendActions(for: .valueChanged)
			self.delegate?.valueChanged(control: self)
			self.updateFieldDisplay()
		}

	}

	// magic to make pop-overs work on iPhone
	func adaptivePresentationStyleForPresentationController(controller:UIPresentationController!) -> UIModalPresentationStyle {
		return .none
	}


	// MARK: - Picker data

	public func numberOfComponents(in pickerView: UIPickerView) -> Int {
		switch (self.dataPickerType) {
		case .HumanHeightIN,
				.HumanHeightCM:
			return 2

		case .HumanWeightLB,
				.HumanWeightKG:
			return 1

		case .MultiArray:
			if let columns:[[String]] = self.multiArrayColumns {
				return columns.count
			}
			return 0

		default:
			return 3
		}
	}


	public func pickerView(_ pickerView:UIPickerView, numberOfRowsInComponent component:Int) -> Int {
		switch (self.dataPickerType) {
		case .HumanHeightIN:
			return (component == 0) ? 9 : 12	//0-8 ft, 0-11 in


		case .HumanHeightCM:
			return (component == 0) ? 3 : 100	//0-2 m, 0-99 cm

		case .HumanWeightLB,
				.HumanWeightKG:
			return 500

		case .MultiArray:
			if let columns:[[String]] = self.multiArrayColumns {
				let rows:[String] = columns[component]
				return rows.count
			}
			return 0

		default:
			return 3

		}
	}

	public func pickerView(_ pickerView:UIPickerView, titleForRow row:Int, forComponent component:Int) -> String? {
		switch (self.dataPickerType) {
		case .HumanHeightIN:
			return (component == 0) ? String(format:"%d ft", row) : String(format:"%d in", row)


		case .HumanHeightCM:
			return (component == 0) ? String(format:"%d", row) : String(format:"%d cm", row)

		case .HumanWeightLB:
			return String(format:"%d lb", row)

		case .HumanWeightKG:
			return String(format:"%d kg", row)

		case .MultiArray:
			if let columns:[[String]] = self.multiArrayColumns {
				let rows:[String] = columns[component]
				if rows.count > row && row > -1 {
					return rows[row]
				}
			}
			return ""

		default:
			return ""

		}
	}


	public func pickerView(_ pickerView:UIPickerView, didSelectRow row:Int, inComponent component:Int) {
		switch (self.dataPickerType) {
		case .HumanHeightIN:

			let feet:Int = pickerView.selectedRow(inComponent: 0)
			let inches:Int = pickerView.selectedRow(inComponent: 1)
			heightValue = Int(((feet * 12) + inches))
			break

		case .HumanHeightCM:

			let m:Int = pickerView.selectedRow(inComponent: 0)
			let cm:Int = pickerView.selectedRow(inComponent: 1)
			heightValue = Int(((m * 100) + cm))
			break

		case .HumanWeightLB,
				.HumanWeightKG:
			weightValue = pickerView.selectedRow(inComponent: 0)
			break

		case .MultiArray:
			var selected:String = ""
			if let columns:[[String]] = self.multiArrayColumns {
				if component < columns.count {
					let rows:[String] = columns[component]
					if row < rows.count {
						selected = rows[row]
					}
				}
			}
			if var multi:[String] = self.multiArrayValue {
				if component > multi.count {
					for pos in 0...component {
						multi.append("")
					}
				}
				multi[component] = selected
				self.multiArrayValue = multi
			}
			break

		default:
			break
		}

		// Picker did Pick: data has changed, alert & update display
		self.sendActions(for: .valueChanged)
		self.delegate?.valueChanged(control: self)

		self.updateFieldDisplay()
	}


	// MARK: - Date Picker data
	@objc func datePickerValueChanged() {
		self.dateValue = _datePicker.date

		// Picker value changed: data has changed, alert & update display
		self.sendActions(for: .valueChanged)
		self.delegate?.valueChanged(control: self)

		self.updateFieldDisplay()
	}


	// MARK: - Data Validation

	public func indicateInvalidData() {
		_primaryfield.layer.borderColor = self.invalidDataIndicatorColor.cgColor
		_secondaryfield?.layer.borderColor = self.invalidDataIndicatorColor.cgColor

		if !self.isValidData() {
			_primaryfield.layer.borderWidth = 1.5
			_primaryfield.layer.cornerRadius = 4.0
			_secondaryfield?.layer.borderWidth = 1.5
			_secondaryfield?.layer.cornerRadius = 4.0
		} else {
			_primaryfield.layer.borderWidth = 0.0
			_secondaryfield?.layer.borderWidth = 0.0
		}
	}

	public func clearInvalidData() {
		_primaryfield.layer.borderWidth = 0.0
		_secondaryfield?.layer.borderWidth = 0.0
	}

	func isValidData() -> Bool {
		self.endEditing(true)	// this forces parsing of the data entry fields

		switch (self.dataPickerType) {
		case .HumanHeightIN, .HumanHeightCM:
			// valid if greater than 10 inches or 10 cm
			return ( (self.heightValue ?? 0) > 10)

		case .HumanWeightLB,
				.HumanWeightKG:
			// valid if not 0
			return (self.weightValue != 0)

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

		case .MultiArray:
			return (self.multiArrayValue != nil)
		}
	}

	public func clearData() {
		self.dateValue = nil
		self.multiArrayValue = nil

		_primaryfield.text = ""

		if  (_secondaryfield != nil)  {
			_secondaryfield?.text = ""
		}

		_primaryfield.layer.borderWidth = 0.0
		_secondaryfield?.layer.borderWidth = 0.0

		self.updateConstraints()
	}

	func makeMultiValueDefault() -> [String] {
		var firstOfEach:[String] = []
		if let columns:[[String]] = self.multiArrayColumns {
			for col in 0...(columns.count - 1) {
				let rows:[String] = columns[col]
				if rows.count > 0 {
					firstOfEach.append(rows[0])
				} else {
					firstOfEach.append("")
				}
			}
		}
		return firstOfEach
	}
}
