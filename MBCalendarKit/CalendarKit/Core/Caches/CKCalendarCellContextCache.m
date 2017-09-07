//
//  CKCalendarCellContextCache.m
//  MBCalendarKit
//
//  Created by Moshe Berman on 9/6/17.
//  Copyright © 2017 Moshe Berman. All rights reserved.
//

#import "CKCalendarModel.h"

#import "CKCalendarCellContextCache.h"
#import "CKCalendarCellContext_Private.h"

#import "NSCalendar+Ranges.h"

@import UIKit;

@interface CKCalendarCellContextCache ()

// MARK: - The Cache

/**
 A cache for the context objects.
 */
@property (nonatomic, strong, nullable) NSMutableDictionary<NSString *, CKCalendarCellContext *> *cache;


// MARK: - The Calendar Used to Describe the Dates

/**
 A calendar used for date calculations.
 */
@property (nonatomic, weak, nullable) CKCalendarModel *model;


// MARK: - Caching Today and Selection

/**
 The context representing the selected cell.
 */
@property (nonatomic, weak, nullable) CKCalendarCellContext *today;

/**
 Cache the context representing the selected cell.
 */
@property (nonatomic, weak, nullable) CKCalendarCellContext *selected;

@end

@implementation CKCalendarCellContextCache

/**
 Initializes the context cache.
 
 @param model The calendar model to use for computing state cache for.
 @return A cell context cache.
 */
- (nonnull instancetype)initWithCalendarModel:(nonnull CKCalendarModel *)model;
{
    self = [super init];
    if(self)
    {
        _cache = [[NSMutableDictionary alloc] init];
        _model = model;
        [self observeLowMemoryNotification];
        [self observeSignificantTimeChanges];
        [self handleSignificantTimeChange];
    }
    
    return self;
}

// MARK: - Accessing the Cache

/**
 Looks up a context object by date.
 
 @param date The date to look up.
 @return A calendar cell context if it exists.
 */
- (nullable CKCalendarCellContext *)contextForDate:(NSDate *)date;
{
    NSString *key = [self keyForDate:date];
    
    CKCalendarCellContext *context = self.cache[key];
    
    if(!context)
    {
        context = [[CKCalendarCellContext alloc] initWithDate:date andCalendarModel:self.model];
        self.cache[key] = context;
    }
    
    return context;
}

// MARK: - Creating a Key

- (nullable NSString *)keyForDate:(nonnull NSDate *)date
{
//    [CKCache.sharedCache.dateFormatter setDateFormat:@"YYYY-MM-dd"];

    NSCalendarUnit units = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay;
    NSDateComponents *components = [self.model.calendar components:units fromDate:date];
    
    char *buffer;
    asprintf(&buffer, "%li-%li-%li", (long)components.year, (long)components.month, (long)components.day);
    NSString *key = [[NSString alloc] initWithCString:buffer encoding:NSUTF8StringEncoding];
    free(buffer);
    
    return key;
}

// MARK: - Handling Selected Date Change

/**
 Called when the calendar's visible date changes.

 @param date The new visible date.
 */
- (void)handleChangeSelectedDateToDate:(NSDate *)date
{
    self.selected.isSelected = NO;
    
    CKCalendarCellContext *context = [self contextForDate:date];
    self.selected = context;
    context.isSelected = YES;
}

/**
 Update the week/month scopes for the contexts.

 @param date The date we're displaying.
 */
- (void)handleScopeChangeForDate:(NSDate *)date
{
    for (NSString *key in self.cache.allKeys)
    {
        CKCalendarCellContext *context = self.cache[key];
        context.isInSameScopeAsVisibleDate = [self.model isDateInSameScopeAsVisibleDateForActiveDisplayMode:context.date];
    }
}

// MARK: - Handle Minimum/Maximum Date Change

/**
 Updates the cache when the minimum date changes.

 @param minimumDate The new minimum date.
 */
- (void)handleNewMinimumDate:(nullable NSDate *)minimumDate;
{
    for (NSString *key in self.cache.allKeys)
    {
        CKCalendarCellContext *context = self.cache[key];
        // This method handles a null minimum date.
        context.isBeforeMinimumDate = [self.model.calendar date:context.date isBeforeDate:minimumDate];
        
    }
}

/**
 Updates the cache when the maximum date changes.
 
 @param maximumDate The new maximum date.
 */
- (void)handleNewMaximumDate:(nullable NSDate *)maximumDate;
{
    for (NSString *key in self.cache.allKeys)
    {
        CKCalendarCellContext *context = self.cache[key];
        // This method handles a null maximum date.
        context.isAfterMaximumDate = [self.model.calendar date:context.date isAfterDate:maximumDate];
    }
}

// MARK: - Handle Changes to NSDate.date

/**
 Register to handle significant time changes.
 */
- (void)observeSignificantTimeChanges
{
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(handleSignificantTimeChange) name:UIApplicationSignificantTimeChangeNotification object:nil];
}

// MARK: - Handling Significant Time Changes

/**
 When there's a significant time change, we want to handle it.
 Simplistic approach is to dump the cache.
 A smarter approach might be to update the cached items to determine the day.
 */
- (void)handleSignificantTimeChange
{
    self.today.isToday = NO;
    
    CKCalendarCellContext *context = [self contextForDate:NSDate.date];
    self.today = context;
    context.isToday = YES;
    
    // If nothing is selected, today is, by default.
    if (!self.selected)
    {
        self.selected = self.today;
    }

}

// MARK: - Handling Low Memory Conditions

- (void)observeLowMemoryNotification
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(purge) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
}

// MARK: - Purging the Cache

- (void)purge
{
    [self.cache removeAllObjects];
}

@end
