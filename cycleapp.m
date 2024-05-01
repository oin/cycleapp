#include <AppKit/AppKit.h>
#import <Cocoa/Cocoa.h>
#include <Foundation/Foundation.h>
#include <unistd.h>

static bool running_only = false;
static bool hide_on_end = false;
static bool return_on_end = false;
static bool hide_on_switch = false;
static bool gentle_switch = false;
static bool verbose = false;
static NSApplicationActivationOptions activationOptions = 0;

static const char* usage_format = 
	"usage: %s [-reEsafv] com.application.bundle-identifier ...\n"
	"\nCycle between the given applications.\n"
	"If the application matching the first given bundle identifier is not running, find it, launch it and activate it. If it is running but not active, activate it. If it is active, repeat with the next application in the list. Once at the end, cycle back to the first application of the list. The behavior can be changed with different options.\n"
	"If this program is called twice with the same arguments in quick succession (less than 100ms), it will hide all the applications on the list and return to the first application before the cycle began.\n"
	"\nOptions:\n"
	"  -r Only cycle between running applications, don't launch anything\n"
	"  -e Hide all applications in the list when at the end (implies -E)\n"
	"  -E Return to the first application before the cycle began when at the end\n"
	"  -s Hide the current application of the list when switching to the next one\n"
	"  -a Bring all the windows to front\n"
	"  -f Use a more forceful application activation method\n"
	"  -v Verbose mode (without arguments, show the bundle identifiers for all the running applications)\n"
	;

static bool on_cycle_end(NSArray *bundleIds, NSRunningApplication *appToReturnTo) {
	if(hide_on_end) {
		// Hide all running applications that are in the list
		for(NSString *bundleId in bundleIds) {
			NSRunningApplication *app = [[NSRunningApplication runningApplicationsWithBundleIdentifier:bundleId] firstObject];
			if(app) {
				if(verbose) {
					printf("Hiding application '%s'\n", app.localizedName.UTF8String);
				}
				[app hide];
			}
		}

		if(appToReturnTo) {
			if(verbose) {
				printf("Activating application '%s'\n", appToReturnTo.localizedName.UTF8String);
			}
			[appToReturnTo activateWithOptions:activationOptions];
		} else if(verbose) {
			printf("No application to return to.");
		}

		return true;
	} else if(return_on_end) {
		[appToReturnTo activateWithOptions:activationOptions];
		return true;
	}
	return false;
}

int main(int argc, char const *argv[]) {
	if(argc == 1) {
		fprintf(stderr, usage_format, argv[0]);
		return 1;
	}

	int c = 0;
	while((c = getopt(argc, (char*const*)argv, "reEsafv")) != -1) {
		switch(c) {
			case 'r':
				running_only = true;
				break;
			case 'e':
				hide_on_end = true;
				break;
			case 'E':
				return_on_end = true;
				break;
			case 's':
				hide_on_switch = true;
				break;
			case 'a':
				activationOptions = NSApplicationActivateAllWindows;
				break;
			case 'f':
				if(activationOptions != NSApplicationActivateAllWindows) {
					activationOptions = NSApplicationActivateIgnoringOtherApps;
				}
				break;
			case 'v':
				verbose = true;
				break;
			default:
				fprintf(stderr, usage_format, argv[0]);
				return 1;
		}
	}
	const size_t size = argc - optind;
	if(size == 0) {
		fprintf(stderr, usage_format, argv[0]);
		if(verbose) {
			printf("\nCurrently running applications:\n");
			for(NSRunningApplication *app in [NSWorkspace sharedWorkspace].runningApplications) {
				if(app.bundleIdentifier.length > 0 && app.bundleURL.absoluteString.length > 0) {
					printf("%s %s: %s\n", app.active? "*" : " ", app.bundleIdentifier.UTF8String, app.localizedName.UTF8String);
				}
			}
			return 1;
		}
		return 1;
	}

	// Create an array of NSStrings from the given application bundle identifiers or names
	const char** bundleids = &argv[optind];
	NSMutableArray *bundleIds = [NSMutableArray arrayWithCapacity:size];
	for(size_t i=0; i<size; i++) {
		[bundleIds addObject:[NSString stringWithUTF8String:bundleids[i]]];
	}

	// Create a unique defaults key for this list of bundle identifiers
	NSString *defaultsKey = [bundleIds componentsJoinedByString:@" "];
	NSString *lastAppBeforeDefaultsKey = [NSString stringWithFormat:@"Last App Before (%@)", defaultsKey];
	NSString *lastActivationTimeDefaultsKey = [NSString stringWithFormat:@"Last Activation Time (%@)", defaultsKey];

	NSDate *lastActivationTime = [NSUserDefaults.standardUserDefaults objectForKey:lastActivationTimeDefaultsKey];
	NSDate *now = [NSDate date];
	bool should_return = false;
	if(lastActivationTime && [now timeIntervalSinceDate:lastActivationTime] < 0.1) {
		should_return = true;
	}
	[NSUserDefaults.standardUserDefaults setObject:now forKey:lastActivationTimeDefaultsKey];

	NSString *bundleIdToReturnTo = [NSUserDefaults.standardUserDefaults objectForKey:lastAppBeforeDefaultsKey];
	NSRunningApplication *appToReturnTo = bundleIdToReturnTo? [[NSRunningApplication runningApplicationsWithBundleIdentifier:bundleIdToReturnTo] firstObject] : nil;

	// Get the current application
	NSRunningApplication *current = [[NSWorkspace sharedWorkspace] frontmostApplication];
	if(!current) {
		fprintf(stderr, "Error: Could not get the frontmost application\n");
		return 2;
	}

	// Find the index of the current application in the list
	NSUInteger index = [bundleIds indexOfObject:current.bundleIdentifier];
	if(should_return) {
		index = size;
		hide_on_end = true;
	}
	if(index == NSNotFound) {
		// Save the current application's bundle identifier to user defaults
		[NSUserDefaults.standardUserDefaults setObject:current.bundleIdentifier forKey:lastAppBeforeDefaultsKey];

		// Use the first application in the list
		index = 0;

		if(verbose) {
			printf("Current application '%s' is not in the list\n", current.localizedName.UTF8String);
		}
	} else {
		// Cycle to the next application in the list
		++index;
		if(index >= size) {
			if(on_cycle_end(bundleIds, appToReturnTo)) {
				return 0;
			}
			index = 0;
		}

		if(hide_on_switch) {
			// Hide the current application
			if(verbose) {
				printf("Hiding application '%s'\n", current.localizedName.UTF8String);
			}
			[current hide];
		}
	}

	// Find the next application in the list
	NSUInteger startingIndex = index;
	while(true) {
		NSString *nextBundleId = bundleIds[index];
		NSRunningApplication *next = [[NSRunningApplication runningApplicationsWithBundleIdentifier:nextBundleId] firstObject];
		if(next) {
			if(verbose) {
				printf("Activating application '%s'\n", next.localizedName.UTF8String);
			}
			[next activateWithOptions:activationOptions];

			return 0;
		} else if(!running_only) {
			// Find the next application
			NSWorkspace	*workspace = [NSWorkspace sharedWorkspace];
			NSURL *url = [workspace URLForApplicationWithBundleIdentifier:nextBundleId];
			if(!url) {
				fprintf(stderr, "Error: Application with bundle identifier '%s' not found\n", nextBundleId.UTF8String);
				return 3;
			}
			// Launch the next application
			NSError *error = nil;
			next = [workspace launchApplicationAtURL:url options:0 configuration:@{} error:&error];
			if(!next) {
				fprintf(stderr, "Error: Could not launch application at URL '%s'%s%s\n", url.absoluteString.UTF8String, error? ": " : "", error? error.localizedDescription.UTF8String : "");
				return 4;
			}

			if(verbose) {
				printf("Launched application '%s', activating.\n", next.localizedName.UTF8String);
			}
			[next activateWithOptions:activationOptions];

			return 0;
		} else {
			++index;
			if(index >= size) {
				if(on_cycle_end(bundleIds, appToReturnTo)) {
					return 0;
				}
				index = 0;
			}
			if(index == startingIndex) {
				if(verbose) {
					printf("No application open in the list. Not doing anything.\n");
				}
				break;
			}
		}
	}

	return 0;
}
