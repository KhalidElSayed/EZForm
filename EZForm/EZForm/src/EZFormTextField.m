//
//  EZForm
//
//  Copyright 2011-2013 Chris Miles. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//  
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//  
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "EZFormTextField.h"
#import "EZForm+Private.h"


typedef enum : NSInteger {
    EZFormTextFieldUserControlTypeNone = 0,
    EZFormTextFieldUserControlTypeTextField = 1,
    EZFormTextFieldUserControlTypeTextView = 2,
    EZFormTextFieldUserControlTypeLabel = 3,
} EZFormTextFieldUserControlType;


@interface UIView (EZFormTextFieldExtension)
@property (readwrite, strong, nonatomic) UIView *inputAccessoryView;
@end


#pragma mark - EZFormTextField class extension

@interface EZFormTextField () {
    TEXTFIELDFILTER inputFilterFn;
}

@property (nonatomic, copy) NSString *internalValue;
@property (nonatomic, strong) NSMutableArray *inputFilterBlocks;
@property (nonatomic, strong) UIView *userControl;
@property (nonatomic, assign) EZFormTextFieldUserControlType userControlType;

@end


#pragma mark - EZFormTextField implementation

@implementation EZFormTextField


#pragma mark - Input Filters

- (void)addInputFilter:(BOOL(^)(id input))inputFilter
{
    [self.inputFilterBlocks addObject:[inputFilter copy]];
}

- (void)removeInputFilters
{
    [self.inputFilterBlocks removeAllObjects];
}

- (void)setInputFilterFunction:(TEXTFIELDFILTER)filterFn
{
    inputFilterFn = filterFn;
}


#pragma mark - Wire up user controls

- (void)useTextField:(UITextField *)textField
{
    [self unwireUserControl];
    
    self.userControl = textField;
    self.userControlType = EZFormTextFieldUserControlTypeTextField;
    [self updateUI];
    [self wireUpUserControl];
}

- (void)useTextView:(UITextView *)textView
{
    [self unwireUserControl];
    
    self.userControl = textView;
    self.userControlType = EZFormTextFieldUserControlTypeTextView;
    [self updateUI];
    [self wireUpUserControl];
}

- (void)useLabel:(UIView *)label
{
    [self unwireUserControl];
    
    self.userControl = label;
    self.userControlType = EZFormTextFieldUserControlTypeLabel;
    [self wireUpUserControl];
    [self updateUI];
}

- (void)wireUpTextField
{
    UITextField *textField = (UITextField *)self.userControl;
    textField.delegate = self;
    [textField addTarget:self action:@selector(textFieldEditingChanged:) forControlEvents:UIControlEventEditingChanged];
    [textField addTarget:self action:@selector(textFieldEditingDidEndOnExit:) forControlEvents:UIControlEventEditingDidEndOnExit];
}

- (void)wireUpTextView
{
    UITextView *textView = (UITextView *)self.userControl;
    textView.delegate = self;
}

- (void)wireUpUserControl
{
    if ([self.userControl isKindOfClass:[UITextField class]]) {
	[self wireUpTextField];
    }
    else if ([self.userControl isKindOfClass:[UITextView class]]) {
	[self wireUpTextView];
    }
    

    if (nil == self.userControl.inputAccessoryView && [self.userControl respondsToSelector:@selector(setInputAccessoryView:)]) {
	// set standard input accessory view, only if one not already assigned
	__strong EZForm *form = self.form;
	self.userControl.inputAccessoryView = [form inputAccessoryView];
    }
}


#pragma mark - Unwire user controls

- (void)unwireTextField
{
    UITextField *textField = (UITextField *)self.userControl;
    [textField removeTarget:self action:@selector(textFieldEditingChanged:) forControlEvents:UIControlEventEditingChanged];
    [textField removeTarget:self action:@selector(textFieldEditingDidEndOnExit:) forControlEvents:UIControlEventEditingDidEndOnExit];
    if (textField.delegate == self) textField.delegate = nil;
}

- (void)unwireTextView
{
    UITextView *textView = (UITextView *)self.userControl;
    if (textView.delegate == self) textView.delegate = nil;
}

- (void)unwireUserControl
{
    if (EZFormTextFieldUserControlTypeTextField == self.userControlType) {
	[self unwireTextField];
    }
    else if (EZFormTextFieldUserControlTypeTextView == self.userControlType) {
	[self unwireTextView];
    }
    
    __strong EZForm *form = self.form;
    if (self.userControl.inputAccessoryView == [form inputAccessoryView] && [self.userControl respondsToSelector:@selector(setInputAccessoryView:)]) {
	// set standard input accessory view, only if one not already assigned
	self.userControl.inputAccessoryView = nil;
    }

    self.userControlType = EZFormTextFieldUserControlTypeNone;
}


#pragma mark - Text field control events

- (void)textFieldEditingChanged:(id)sender
{
    UITextField *textField = (UITextField *)sender;
    [self setFieldValue:textField.text canUpdateView:NO];
    [self updateValidityIndicators];
}

- (void)textFieldEditingDidEndOnExit:(id)sender
{
    #pragma unused(sender)
    
    __strong EZForm *form = self.form;
    [form formFieldInputFinished:self];
}


#pragma mark - Is input valid

- (BOOL)isInputValid:(NSString *)inputStr
{
    if (self.inputMaxCharacters > 0 && [inputStr length] > self.inputMaxCharacters) {
	return NO;
    }
    
    for (BOOL (^filterBlock)(id text) in self.inputFilterBlocks) {
	if (!filterBlock(inputStr)) {
	    return NO;
	}
    }
    
    if (inputFilterFn) {
	if (!inputFilterFn(inputStr)) {
	    return NO;
	}
    }
    
    return YES;
}


#pragma mark - Invalid indicator view

- (void)setTextFieldInvalidIndicatorView:(UIView *)view viewMode:(UITextFieldViewMode)viewMode
{
    if (_invalidIndicatorPosition == EZFormTextFieldInvalidIndicatorPositionRight) {
	[(UITextField *)self.userControl setRightViewMode:viewMode];
	[(UITextField *)self.userControl setRightView:view];
    }
    else if (_invalidIndicatorPosition == EZFormTextFieldInvalidIndicatorPositionLeft) {
	[(UITextField *)self.userControl setLeftViewMode:viewMode];
	[(UITextField *)self.userControl setLeftView:view];
    }
}

- (void)updateValidityIndicators
{
    if (self.invalidIndicatorView) {
	// ** Currently only supported by UITextField views
	
	if (EZFormTextFieldUserControlTypeTextField == self.userControlType) {
	    if ([self isValid]) {
		[self setTextFieldInvalidIndicatorView:nil viewMode:UITextFieldViewModeNever];
	    }
	    else {
		[self setTextFieldInvalidIndicatorView:self.invalidIndicatorView viewMode:UITextFieldViewModeAlways];
	    }
	}
    }
}

- (void)updateUIWithValue:(NSString *)value
{
    if (EZFormTextFieldUserControlTypeTextField == self.userControlType) {
	[(UITextField *)self.userControl setText:value];
    }
    else if (EZFormTextFieldUserControlTypeTextView == self.userControlType) {
	[(UITextView *)self.userControl setText:value];
    }
    else if (EZFormTextFieldUserControlTypeLabel == self.userControlType) {
	[(UILabel *)self.userControl setText:value];
    }
    
    [self updateValidityIndicators];
}

- (void)updateUI
{
    [self updateUIWithValue:[self fieldValue]];
}

- (BOOL)formFieldWithText:(NSString *)text shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    NSString *resultingString = [text stringByReplacingCharactersInRange:range withString:string];
    
    if (self.trimWhitespace) {
	if (self.inputMaxCharacters > 0 && [resultingString length] > self.inputMaxCharacters) {
	    // Prevent non-trimmed string from exceeding max chars
	    return NO;
	}
	
	resultingString = [resultingString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    
    BOOL result = [self isInputValid:resultingString];
    return result;
}


#pragma mark - EZFormFieldConcrete methods

- (BOOL)typeSpecificValidation
{
    BOOL result = YES;
    
    NSString *value = [self fieldValue];
    if (self.validationMinCharacters > 0 && [value length] < self.validationMinCharacters) {
	result = NO;
    }
    
    return result;
}

- (void)updateView
{
    [self updateUI];
}


#pragma mark - UITextFieldDelegate methods

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    #pragma unused(textField)
    
    __strong EZForm *form = self.form;
    [form formFieldDidBeginEditing:self];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    return [self formFieldWithText:textField.text shouldChangeCharactersInRange:range replacementString:string];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    #pragma unused(textField)

    return YES;
}


#pragma mark - UITextViewDelegate methods

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    #pragma unused(textView)

    __strong EZForm *form = self.form;
    [form formFieldDidBeginEditing:self];
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    return [self formFieldWithText:textView.text shouldChangeCharactersInRange:range replacementString:text];
}

- (void)textViewDidChange:(UITextView *)textView
{
    [self setFieldValue:textView.text canUpdateView:NO];
    [self updateValidityIndicators];
}


#pragma mark - EZFormField methods

- (id)actualFieldValue
{
    NSString *value = self.internalValue;
    if (self.trimWhitespace) {
	value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }

    return value;
}

- (void)setActualFieldValue:(id)value
{
    if (value) {
	self.internalValue = [NSString stringWithFormat:@"%@", value];
    }
    else {
	self.internalValue = value;
    }
}

- (void)becomeFirstResponder
{
    [self.userControl becomeFirstResponder];
}

- (void)resignFirstResponder
{
    [self.userControl resignFirstResponder];
}

- (BOOL)canBecomeFirstResponder
{
    return [self.userControl canBecomeFirstResponder];
}

- (BOOL)isFirstResponder
{
    return [self.userControl isFirstResponder];
}

- (UIView *)userView
{
    return self.userControl;
}

- (void)unwireUserViews
{
    [self unwireUserControl];
}

- (BOOL)acceptsKeyboardAccessory
{
    return [self.userControl respondsToSelector:@selector(setInputAccessoryView:)];
}

- (void)setInputAccessoryView:(UIView *)inputAccessoryView
{
    [(UITextField *)self.userControl setInputAccessoryView:inputAccessoryView];
}

- (UIView *)inputAccessoryView
{
    return self.userControl.inputAccessoryView;
}


#pragma mark - Memory Management

- (id)initWithKey:(NSString *)aKey
{
    if ((self = [super initWithKey:aKey])) {
	_trimWhitespace = YES;
	_invalidIndicatorPosition = EZFormTextFieldInvalidIndicatorPositionRight;
	_inputFilterBlocks = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (void)dealloc
{
    [self unwireUserControl];
}

@end
