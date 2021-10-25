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
	func beganTextInput()
	func beganShowPicker()
}

open class DataEntryPicker : UIControl, UITextFieldDelegate, UIPickerViewDelegate, UIPickerViewDataSource, UIPopoverPresentationControllerDelegate {

	// behavior and delegates
	public var delegate:DataEntryPickerDelegate?
	public var dataPickerType:DataEntryPickerType = .MultiArray
	public var showKeyaboard:Bool = false
	public var nextInputField:UIResponder?
	public var inputAssistantViewController:UIViewController?

	// component column setup for Generic type (dates are automatic, height is hardcoded)
	public var multiArrayColumns:[[String]]? = []

	// resulting user-picked values
	public var heightValue:Int! = 0
	public var weightValue:Int! = 0
	public var dateValue:Date?
	public var multiArrayValue:[String]?

	// design
	public var labelTextColor:UIColor! = UIColor.black
	public var buttonIcon:UIImage?
	public var buttonTextColor:UIColor! = UIColor.black
	public var buttonBackgroundColor:UIColor! = UIColor.systemGray2
	public var buttonShadowColor:UIColor! = UIColor.systemGray4
	public var invalidDataIndicatorColor:UIColor! = UIColor.red
	let multiArrayDisplaySeparator = ","


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
	private var _secondaryfield:UITextField?
	var secondaryfield:UITextField? {
		get { return _secondaryfield }
		set { _secondaryfield = newValue }
	}
	private var _secondarylabel:UILabel?
	var secondarylabel:UILabel? {
		get { return _secondarylabel }
		set { _secondarylabel = newValue }
	}
	private var _button:UIButton?
	var button:UIButton? {
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

		if let icon = self.buttonIcon {
			self.button = UIButton()
			if let button = self.button {
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
		self.dateformatter = DateFormatter()
		self.dateformatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "MMddyy",
																					options:0,
																					locale:locale)


		// Vertical layout - these don't change so set them here
		var viewsDictionary:[String:Any] = ["_primaryfield": _primaryfield!, "_primarylabel": _primarylabel!, "self": self]
		self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[_primaryfield]|", metrics: nil, views: viewsDictionary))
		self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[_primarylabel]|", metrics: nil, views: viewsDictionary))
		if _button != nil {
			viewsDictionary["_button"] = _button
			self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[_button]|", metrics: nil, views: viewsDictionary))
		}


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
		case .HumanHeightIN:

			// setup if needed
			if nil == self.secondaryfield {

				self.secondaryfield = UITextField()
				if let field = self.secondaryfield {
					field.delegate = self
					field.borderStyle = .roundedRect
					field.returnKeyType = .next
					field.keyboardType = .numbersAndPunctuation
					field.autocorrectionType = .no
					field.translatesAutoresizingMaskIntoConstraints = false
					field.backgroundColor = self.primaryfield.backgroundColor
					field.tintColor = self.primaryfield.tintColor

					self.addSubview(field)
				}

				self.secondarylabel = UILabel()
				if let label = self.secondarylabel {
					label.translatesAutoresizingMaskIntoConstraints = false
					self.addSubview(label)
				}


				// Vertical layout - these don't change so set them once
				let viewsDictionary:[String:Any] = ["_secondaryfield": _secondaryfield!, "_secondarylabel": _secondarylabel!, "self": self]
				self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[_secondaryfield]|", metrics: nil, views: viewsDictionary))
				self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[_secondarylabel]|", metrics: nil, views: viewsDictionary))
			}

			// layout for FEET type
			self.primarylabel.text = NSLocalizedString("ft", comment:"abbreviation for feet in U.S. customary measuring system")
			self.secondarylabel?.text = NSLocalizedString("in", comment:"abbreviation for inches in U.S. customary measuring system")

			// Horizontal layout
			if _button != nil {
				let viewsDictionary:[String:Any] = ["_primaryfield": _primaryfield!, "_primarylabel": _primarylabel!, "_secondaryfield": _secondaryfield!, "_secondarylabel": _secondarylabel!, "_button": _button!, "self": self]
				self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[_primaryfield]-2-[_primarylabel(==24)]-[_secondaryfield(==_primaryfield)]-2-[_secondarylabel(==24)]-2-[_button(==24)]|", metrics: nil, views: viewsDictionary))
			} else {
				let viewsDictionary:[String:Any] = ["_primaryfield": _primaryfield!, "_primarylabel": _primarylabel!, "_secondaryfield": _secondaryfield!, "_secondarylabel": _secondarylabel!, "self": self]
				self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[_primaryfield]-2-[_primarylabel(==24)]-[_secondaryfield(==_primaryfield)]-2-[_secondarylabel(==24)]|", metrics: nil, views: viewsDictionary))
			}
			break

		case .HumanHeightCM:

			// layout for CENTIMETER type
			self.primarylabel.text = NSLocalizedString("cm", comment:"abbreviation for centimeters")

			// Horizontal layout
			if _button != nil {
				let viewsDictionary:[String:Any] = ["_primaryfield": _primaryfield!, "_primarylabel": _primarylabel!, "_button": _button!, "self": self]
				self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[_primaryfield]-2-[_primarylabel(==_primaryfield)]-2-[_button(==24)]|", metrics: nil, views: viewsDictionary))
			} else {
				let viewsDictionary:[String:Any] = ["_primaryfield": _primaryfield!, "_primarylabel": _primarylabel!, "self": self]
				self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[_primaryfield]-2-[_primarylabel(==_primaryfield)]|", metrics: nil, views: viewsDictionary))
			}
			break

		case .HumanWeightLB:

			// layout for POUNDS type
			self.primarylabel.text = NSLocalizedString("lb", comment:"abbreviation for pound weight")

			// Horizontal layout
			if _button != nil {
				let viewsDictionary:[String:Any] = ["_primaryfield": _primaryfield!, "_primarylabel": _primarylabel!, "_button": _button!, "self": self]
				self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[_primaryfield]-2-[_primarylabel(==_primaryfield)]-2-[_button(==24)]|", metrics: nil, views: viewsDictionary))
			} else {
				let viewsDictionary:[String:Any] = ["_primaryfield": _primaryfield!, "_primarylabel": _primarylabel!, "self": self]
				self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[_primaryfield]-2-[_primarylabel(==_primaryfield)]|", metrics: nil, views: viewsDictionary))
			}
			break

		case .HumanWeightKG:

			// layout for KILOGRAM type
			self.primarylabel.text = NSLocalizedString("kg", comment:"abbreviation for kilogram weight")

			// Horizontal layout
			if _button != nil {
				let viewsDictionary:[String:Any] = ["_primaryfield": _primaryfield!, "_primarylabel": _primarylabel!, "_button": _button!, "self": self]
				self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[_primaryfield]-2-[_primarylabel(==_primaryfield)]-2-[_button(==24)]|", metrics: nil, views: viewsDictionary))
			} else {
				let viewsDictionary:[String:Any] = ["_primaryfield": _primaryfield!, "_primarylabel": _primarylabel!, "self": self]
				self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[_primaryfield]-2-[_primarylabel(==_primaryfield)]|", metrics: nil, views: viewsDictionary))
			}
			break

		case .MultiArray:

			self.primarylabel.text = ""

			// Horizontal layout
			if _button != nil {
				let viewsDictionary:[String:Any] = ["_primaryfield": _primaryfield!, "_button": _button!, "self": self]
				self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[_primaryfield]-2-[_button(==24)]|", metrics: nil, views: viewsDictionary))
			} else {
				let viewsDictionary:[String:Any] = ["_primaryfield": _primaryfield!, "self": self]
				self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[_primaryfield]|", metrics: nil, views: viewsDictionary))
			}
			break

		default:
			// layout for DATE type
			self.primaryfield.placeholder = self.dateformatter.dateFormat

			self.primarylabel.removeFromSuperview()

			// Horizontal layout
			if _button != nil {
				let viewsDictionary:[String:Any] = ["_primaryfield": _primaryfield!, "_button": _button!, "self": self]
				self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[_primaryfield]-2-[_button(==24)]|", metrics: nil, views: viewsDictionary))
			} else {
				let viewsDictionary:[String:Any] = ["_primaryfield": _primaryfield!, "self": self]
				self.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[_primaryfield]|", metrics: nil, views: viewsDictionary))
			}
			break
		}

		if let button = self.button {
			button.setTitleColor(self.buttonTextColor, for:.normal)
			button.backgroundColor = self.buttonBackgroundColor
			button.layer.shadowColor = self.buttonShadowColor.cgColor
		}

		self.primarylabel.textColor = self.labelTextColor
		self.primaryfield.keyboardAppearance = self.keyboardAppearance

		if secondarylabel != nil {
			self.secondarylabel?.textColor = self.labelTextColor
		}


	}

	open override func layoutSubviews() {
		super.layoutSubviews()
		self.updateFieldDisplay()
	}

	func updateFieldDisplay() {
		switch (self.dataPickerType) {
		case .HumanHeightIN:

			let feet:Int = self.heightValue / 12
			let inches:Int = self.heightValue % 12

			if feet > 0 {
				self.primaryfield.text = String(format:"%d", feet)
			} else {
				self.primaryfield.text = ""
			}
			if inches > 0 {
				self.secondaryfield?.text = String(format:"%d", inches)
			} else {
				self.secondaryfield?.text = ""
			}

			break

		case .HumanHeightCM:
			if self.heightValue > 0 {
				self.primaryfield.text = String(format:"%d", self.heightValue)
			} else {
				self.primaryfield.text = ""
			}
			break

		case .HumanWeightLB, .HumanWeightKG:
			if self.weightValue > 0 {
				self.primaryfield.text = String(format:"%d", self.weightValue)
			} else {
				self.primaryfield.text = ""
			}
			break

		case .MultiArray:
			if let multi = self.multiArrayValue {
				self.primaryfield.text = multi.joined(separator: "\(multiArrayDisplaySeparator) ")
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
		self.secondaryfield?.resignFirstResponder()
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

		// only allow picker input (no keyboard)
		if showKeyaboard {
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
		if textField == self.primaryfield && nil != self.secondaryfield {
			self.secondaryfield?.becomeFirstResponder()
		} else {
			if self.dataPickerType == .HumanHeightIN  {
				let feet:Int = Int(self.primaryfield.text ?? "0") ?? 0
				let inches:Int = Int(self.secondaryfield?.text ?? "0") ?? 0
				self.heightValue = Int(((feet * 12) + inches))

			} else if self.dataPickerType == .HumanHeightCM  {
				self.heightValue = Int(self.primaryfield.text ?? "0") ?? 0

			} else if self.dataPickerType == .HumanWeightLB ||  self.dataPickerType == .HumanWeightKG  {
				self.weightValue = Int(self.primaryfield.text ?? "0") ?? 0
			}

			self.nextInputField?.becomeFirstResponder()
		}

		self.updateFieldDisplay()

		return false
	}

	public func textFieldDidEndEditing(_ textField:UITextField) {
		switch (self.dataPickerType) {
		case .HumanHeightIN:

			let feet:Int = Int(self.primaryfield.text ?? "0") ?? 0
			let inches:Int = Int(self.secondaryfield?.text ?? "0") ?? 0
			self.heightValue = Int(((feet * 12) + inches))

			break

		case .HumanHeightCM:
			self.heightValue = Int(self.primaryfield.text ?? "0") ?? 0
			break

		case .HumanWeightLB, .HumanWeightKG:
			self.weightValue = Int(self.primaryfield.text ?? "0") ?? 0
			break

		case .MultiArray:
			if let splitText = self.primaryfield.text?.split(separator: Character(multiArrayDisplaySeparator)) {
				var selected:[String] = []
				for pos in 0...(splitText.count - 1) {
					selected.append(String(splitText[pos]).trimmingCharacters(in: .whitespacesAndNewlines))
				}
				self.multiArrayValue = selected
			}
			break

		default:
			self.dateValue = self.dateformatter.date(from: self.primaryfield.text ?? "")
			break
		}

		// Text Field did End: data has changed, alert & update display
		self.sendActions(for: .valueChanged)

		self.updateFieldDisplay()

	}


	// MARK: - Picker presentation

	@objc func showPicker() {
		self.delegate?.beganShowPicker()

		self.primaryfield.resignFirstResponder()
		self.secondaryfield?.resignFirstResponder()
		self.primaryfield.layer.borderWidth = 0.0
		self.secondaryfield?.layer.borderWidth = 0.0

		self.pickerController = UIViewController()

		var picker:UIPickerView!
		var datepicker:UIDatePicker!

		if self.dataPickerType == .HumanHeightIN
				|| self.dataPickerType == .HumanHeightCM
				|| self.dataPickerType == .HumanWeightLB
				|| self.dataPickerType == .HumanWeightKG
				|| self.dataPickerType == .MultiArray  {
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
			case .HumanHeightIN:
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

			case .HumanWeightLB, .HumanWeightKG:
				picker.selectRow(self.weightValue, inComponent: 0, animated: true)
				break

			case .PastDate:
				if let date:Date = self.dateValue {
					datepicker.setDate(date, animated:true)
				} else {
					datepicker.setDate(Date.init(timeIntervalSinceNow: -32000000), animated:true) // before last year-ish
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
					datepicker.setDate(Date.init(timeIntervalSinceNow: 32000000), animated:true) // after next year-ish
				}
				break

			case .MultiArray:
				if let multi:[String] = self.multiArrayValue, let columns:[[String]] = self.multiArrayColumns {
					for col in 0...(columns.count - 1) {
						let rows:[String] = columns[col]
						for row in 0...(rows.count - 1) {
							if col < multi.count && multi[col] == rows[row] {
								picker.selectRow(row, inComponent: col, animated: true)
							}
						}
					}

				} else {
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
					self.multiArrayValue = firstOfEach
				}
				break
			}

			DispatchQueue.main.async {
				// default Picker values selected: data has changed, alert & update display
				self.sendActions(for: .valueChanged)
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
				multi[component] = selected
				self.multiArrayValue = multi
			}
			break

		default:
			break
		}

		// Picker did Pick: data has changed, alert & update display
		self.sendActions(for: .valueChanged)

		self.updateFieldDisplay()
	}


	// MARK: - Date Picker data
	@objc func datePickerValueChanged(datepicker:UIDatePicker!) {
		self.dateValue = datepicker.date

		// Picker value changed: data has changed, alert & update display
		self.sendActions(for: .valueChanged)

		self.updateFieldDisplay()
	}


	// MARK: - Data Validation

	func indicateInvalidData() {
		// should we pass in a boolean to turn this On/Off so we don't rely on the internal isValidData call?
		// what if we want to do validation outside of PCI rules?

		self.primaryfield.layer.borderColor = self.invalidDataIndicatorColor.cgColor
		self.secondaryfield?.layer.borderColor = self.invalidDataIndicatorColor.cgColor

		if !self.isValidData() {
			self.primaryfield.layer.borderWidth = 1.5
			self.primaryfield.layer.cornerRadius = 4.0
			self.secondaryfield?.layer.borderWidth = 1.5
			self.secondaryfield?.layer.cornerRadius = 4.0
		} else {
			self.primaryfield.layer.borderWidth = 0.0
			self.secondaryfield?.layer.borderWidth = 0.0
		}
	}

	func clearInvalidData() {
		self.primaryfield.layer.borderWidth = 0.0
		self.secondaryfield?.layer.borderWidth = 0.0
	}

	func isValidData() -> Bool {
		self.endEditing(true)	// this forces parsing of the data entry fields

		switch (self.dataPickerType) {
		case .HumanHeightIN:
			// valid if greater than 10 inches
			return (self.heightValue > 10)

		case .HumanHeightCM:
			// valid if greater than 10 cm
			return (self.heightValue > 10)

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

	func clearData() {
		self.dateValue = nil
		self.multiArrayValue = nil

		self.primaryfield.text = ""

		if  (self.secondaryfield != nil)  {
			self.secondaryfield?.text = ""
		}

		self.primaryfield.layer.borderWidth = 0.0
		self.secondaryfield?.layer.borderWidth = 0.0

		self.updateConstraints()
	}
}
