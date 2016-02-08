//
//  FTXLBaseTableViewCell.m
//  ALJ
//
//  Created by Alex Zdorovets on 5/21/15.
//  Copyright (c) 2015 Alex Zdorovets. All rights reserved.
//

#import "FTXLBaseTableViewCell.h"

#import "XLForm.h"

#import "XLForm+Helpers.h"

#import "XLFormPresenters.h"

#import "XLFormContent.h"

@interface FTXLBaseTableViewCell () <UIPickerViewDataSource, UIPickerViewDelegate>

@property (nonatomic, strong) XLFormPresenter *presenter;

@property (nonatomic, strong) UIPickerView *pickerView;
@property (nonatomic, strong) UIDatePicker *datePicker;
@property (nonatomic, strong) XLFormRowDescriptor *inlineFormRowDescriptor;

@end

@implementation FTXLBaseTableViewCell

@synthesize errorView;

- (void)awakeFromNib {
    [super awakeFromNib];
    self.backgroundColor = [UIColor clearColor];
    [self update];
}

- (void)update {
    [super update];
    [self updateError];
}

+ (void)load {
    [[XLRowTypesStorage cellClassesForRowDescriptorTypes:[UITableView class]] setObject:[[self class] identifier] forKey:[[self class] identifier]];
}

#pragma mark - XLFormDescriptorCell protocol

-(UIView *)inputView {
    if (self.rowDescriptor.selectionStyle == XLFormRowSelectionStylePicker) {
        if (self.rowDescriptor.selectionType == XLFormRowSelectionTypePickerView) {
            return self.pickerView;
        }
        if (self.rowDescriptor.selectionType == XLFormRowSelectionTypeDatePicker) {
            return self.datePicker;
        }
    }
    return [super inputView];
}

-(BOOL)formDescriptorCellCanBecomeFirstResponder {
    if(self.rowDescriptor.selectionStyle == XLFormRowSelectionStyleInline || self.rowDescriptor.selectionStyle == XLFormRowSelectionStylePicker) {
        return !self.rowDescriptor.isDisabled;
    }
    return NO;
}

-(BOOL)formDescriptorCellBecomeFirstResponder {
    if(self.rowDescriptor.selectionStyle == XLFormRowSelectionStyleInline) {
        if ([self isFirstResponder]){
            [self resignFirstResponder];
            return NO;
        }
        return [self becomeFirstResponder];
    }
    return [self becomeFirstResponder];
}

- (BOOL)canBecomeFirstResponder {
    if(self.rowDescriptor.selectionStyle == XLFormRowSelectionStyleInline) {
        if(self.rowDescriptor.selectionType == XLFormRowSelectionTypePickerView) {
            return self.rowDescriptor.selectorOptions.count && !self.rowDescriptor.isDisabled;
        } else if(self.rowDescriptor.selectionType == XLFormRowSelectionTypeDatePicker) {
            return !self.rowDescriptor.isDisabled;
        }
    } else if(self.rowDescriptor.selectionStyle == XLFormRowSelectionStylePicker) {
        return !self.rowDescriptor.isDisabled;
    }
    return [super canBecomeFirstResponder];
}

- (BOOL)becomeFirstResponder {
    BOOL result = NO;
    BOOL shouldBecome = [self.formViewController formRowDescriptorShouldBecomeResponderer:self.rowDescriptor];
    if(!shouldBecome) {
        return NO;
    }
    if(self.rowDescriptor.selectionStyle == XLFormRowSelectionStyleInline) {
        if (self.isFirstResponder){
            result = [super becomeFirstResponder];
        } else {
            result = [super becomeFirstResponder];
            if (result) {
                NSString *type = nil;
                switch (self.rowDescriptor.selectionType) {
                    case XLFormRowSelectionTypeDatePicker: {
                        type = XLFormRowDescriptorTypeDatePicker;
                        if(!self.rowDescriptor.value) {
                            self.rowDescriptor.value = [NSDate date];
                        }
                    }
                        break;
                    case XLFormRowSelectionTypePickerView:
                        type = XLFormRowDescriptorTypePicker;
                        break;
                    default:
                        break;
                }
                if(!self.rowDescriptor.value) {
                    self.rowDescriptor.value = [self.rowDescriptor.selectorOptions firstObject];
                }
                XLFormRowDescriptor * inlineRowDescriptor = [XLFormRowDescriptor formRowDescriptorWithTag:nil rowType:type];
                [inlineRowDescriptor.cellConfig setValuesForKeysWithDictionary:self.rowDescriptor.cellConfigIfInlined];
                id<XLFormDescriptorCell> cell = [inlineRowDescriptor cell];
                NSAssert([cell conformsToProtocol:@protocol(XLFormInlineRowDescriptorCell)], @"inline cell must conform to XLFormInlineRowDescriptorCell");
                id<XLFormInlineRowDescriptorCell> inlineCell = cell;
                inlineCell.inlineRowDescriptor = self.rowDescriptor;
                [(UIView*)inlineCell setBackgroundColor:[UIColor clearColor]];
                [self.rowDescriptor.sectionDescriptor addFormRow:inlineRowDescriptor afterRow:self.rowDescriptor];
                [self.formViewController.formContent ensureRowIsVisible:inlineRowDescriptor];
            }
        }
    } else {
        result = [super becomeFirstResponder];
    }
    return result;
}

- (BOOL)resignFirstResponder {
    BOOL result = NO;
    BOOL shouldResign = [self.formViewController formRowDescriptorShouldResignResponderer:self.rowDescriptor];
    if(!shouldResign) {
        return result;
    }
    if(self.rowDescriptor.selectionStyle == XLFormRowSelectionStyleInline) {
        NSIndexPath * selectedRowPath = [self.formViewController.form indexPathOfFormRow:self.rowDescriptor];
        NSIndexPath * nextRowPath = [NSIndexPath indexPathForRow:selectedRowPath.row + 1 inSection:selectedRowPath.section];
        XLFormRowDescriptor * nextFormRow = [self.formViewController.form formRowAtIndex:nextRowPath];
        XLFormSectionDescriptor * formSection = [self.formViewController.form.formSections objectAtIndex:nextRowPath.section];
        result = [super resignFirstResponder];
        [formSection removeFormRow:nextFormRow];
    } else {
        result = [super resignFirstResponder];
    }
    return result;
}

-(void)formDescriptorCellDidSelectedWithFormController:(XLFormViewController *)controller {
    [self performSelectionWithFormController:controller];
//    if(self.rowDescriptor.selectionStyle != XLFormRowSelectionStyleUndefined) {
//        
//    }
}

#pragma mark - Hightlight

- (void)highlight {
    [self.formViewController formRowDescriptorHasChangeHidhlight:self.rowDescriptor hightlight:YES];
}

- (void)unhighlight {
    [self.formViewController formRowDescriptorHasChangeHidhlight:self.rowDescriptor hightlight:NO];
}

#pragma mark - Accessors

-(UIPickerView *)pickerView {
    if (_pickerView) return _pickerView;
    _pickerView = [[UIPickerView alloc] init];
    _pickerView.delegate = self;
    _pickerView.dataSource = self;
    if(!self.rowDescriptor.value) {
        self.rowDescriptor.value = [self.rowDescriptor.selectorOptions firstObject];
    }
    [_pickerView selectRow:[self selectedIndex] inComponent:0 animated:NO];
    return _pickerView;
}

// TODO: don't forget setup range, current date.

-(UIDatePicker *)datePicker {
    if (_datePicker) return _datePicker;
    _datePicker = [[UIDatePicker alloc] init];
    [_datePicker addTarget:self action:@selector(datePickerValueChanged:) forControlEvents:UIControlEventValueChanged];
    return _datePicker;
}

- (void)datePickerValueChanged:(UIDatePicker *)sender {
    self.rowDescriptor.value = sender.date;
    [self update];
    [self setNeedsLayout];
}

#pragma mark - Utils

- (void)updateError {
    [self.errorView setError:self.rowDescriptor.error];
}

- (void)performSelectionWithFormController:(XLFormViewController *)viewController {
    Class presenterClass = nil;
    switch (self.rowDescriptor.selectionStyle) {
        case XLFormRowSelectionStylePush: presenterClass = [XLFormPushPresenter class]; break;
        case XLFormRowSelectionStylePresent: presenterClass = [XLFormModalPresenter class]; break;
        case XLFormRowSelectionStyleActionSheet: presenterClass = [XLFormActionSheetPresenter class]; break;
        case XLFormRowSelectionStyleAlertView: presenterClass = [XLFormAlertViewPresenter class]; break;
        case XLFormRowSelectionStylePopover: presenterClass = [XLFormPopoverPresenter class]; break;
        case XLFormRowSelectionStyleInline:
        case XLFormRowSelectionStylePicker:
            presenterClass = nil;
            break;
        default: presenterClass = [XLFormSeguePresenter class]; break;
    }
    if(presenterClass) {
        XLFormPresenter *presenter = [[presenterClass alloc] init];
        presenter.sourceViewController = viewController;
        presenter.rowDescriptor = self.rowDescriptor;
        [presenter presentWithCompletionBlock:nil];
        self.presenter = presenter;
    }
}

-(NSString *)valueDisplayText {
    
    if(self.rowDescriptor.mutlipleSelection) {
        if (!self.rowDescriptor.value || [self.rowDescriptor.value count] == 0){
            return self.rowDescriptor.noValueDisplayText;
        }
        
        if (self.rowDescriptor.valueTransformer){
            NSAssert([self.rowDescriptor.valueTransformer isSubclassOfClass:[NSValueTransformer class]], @"valueTransformer is not a subclass of NSValueTransformer");
            NSValueTransformer * valueTransformer = [self.rowDescriptor.valueTransformer new];
            NSString * tranformedValue = [valueTransformer transformedValue:self.rowDescriptor.value];
            if (tranformedValue){
                return tranformedValue;
            }
        }
    }
    
//    if ([self.rowDescriptor.rowType isEqualToString:XLFormRowDescriptorTypeMultipleSelector] || [self.rowDescriptor.rowType isEqualToString:XLFormRowDescriptorTypeMultipleSelectorPopover]){
//        NSMutableArray * descriptionArray = [NSMutableArray arrayWithCapacity:[self.rowDescriptor.value count]];
//        for (id option in self.rowDescriptor.selectorOptions) {
//            NSArray * selectedValues = self.rowDescriptor.value;
//            if ([selectedValues formIndexForItem:option] != NSNotFound){
//                if (self.rowDescriptor.valueTransformer){
//                    NSAssert([self.rowDescriptor.valueTransformer isSubclassOfClass:[NSValueTransformer class]], @"valueTransformer is not a subclass of NSValueTransformer");
//                    NSValueTransformer * valueTransformer = [self.rowDescriptor.valueTransformer new];
//                    NSString * tranformedValue = [valueTransformer transformedValue:option];
//                    if (tranformedValue){
//                        [descriptionArray addObject:tranformedValue];
//                    }
//                }
//                else{
//                    [descriptionArray addObject:[option displayText]];
//                }
//            }
//        }
//        return [descriptionArray componentsJoinedByString:@", "];
//    }
    if (!self.rowDescriptor.value){
        return self.rowDescriptor.noValueDisplayText;
    }
    if (self.rowDescriptor.valueTransformer){
        NSAssert([self.rowDescriptor.valueTransformer isSubclassOfClass:[NSValueTransformer class]], @"valueTransformer is not a subclass of NSValueTransformer");
        NSValueTransformer * valueTransformer = [self.rowDescriptor.valueTransformer new];
        NSString * tranformedValue = [valueTransformer transformedValue:self.rowDescriptor.value];
        if (tranformedValue){
            return tranformedValue;
        }
    }
    return [self.rowDescriptor formattedValue];
}

#pragma mark - UIPickerViewDelegate

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    id value = [self.rowDescriptor.selectorOptions objectAtIndex:row];
    return [self.rowDescriptor formatValue:value];

}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    id value = [self.rowDescriptor.selectorOptions objectAtIndex:row];
    if([value respondsToSelector:@selector(formValue)]) {
        value = [value formValue];
    }
    self.rowDescriptor.value = value;
}

#pragma mark - UIPickerViewDataSource

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return self.rowDescriptor.selectorOptions.count;
}

#pragma mark - helpers

- (NSInteger)selectedIndex {
    XLFormRowDescriptor * formRow = self.rowDescriptor;
    NSInteger index = [formRow.selectorOptions indexOfObject:formRow.value];
    return index != NSNotFound ? index : -1;
}
@end
