LocalizedStringsTool

1. What is it
LocalizedStringsTool is a tool that performs LocalizedStrings analisys  and helps you to clean up your translations
If you use SwiftGen or R you don’t need this tool


1. What is it for
LocalizedStringsTool can help you to find:
- Untranslated keys in your code
- Unused translations 
- Translation duplications
- Difference in keys set for every languages pair

1. How to use
-prepare your custom settings file LocalizedStringsTool.plist or use default one (see next point to understand settings)
Just download main.swift file and execute it in your terminal 

$ swift <path to main.swift>


1. How to setup LocalizedStringsTool.plist 
projectRootFolderPath
Absolute path to your project root folder

unusedTranslations
Enable or disable searching for unused translations in your Localizable.strings files

translationDuplication
Enable or disable searching for translation duplications in your Localizable.strings files
(Several different keys with the same value (translation string))

untranslatedKeys
Enable or disable searching for keys without translation in your source code 

allUntranslatedStrings
Temporary unavailable

differentKeysInTranslations
Enable or disable searching for key sets difference for language pairs
For example “en” has 100 keys and “ru” was 110 keys. Most likely you want to have the same keys for any language and now you can see absent or added keys

shouldAnalyzeSwift
Enable or disable analyzing Swift files

shouldAnalyzeObjC
Enable or disable analyzing Objective C files

customSwiftPatternPrefixes
If you use some custom wrappers for  NSLocalizedString(@"key", @"comment")
For example it can be lang(“myKey”) and you should add here “lang\”

customSwiftPatternSuffixes
The same but for suffixes. Add “.localized” if you use “myKey”.localized instead of  NSLocalizedString(@"key", @"comment")

customObjCPatternPrefixes
The same but for Obj C. Also add here prefixes that can help the program to find keys in source code
For example if you use keys as func parameters and made localisation inside it.

- (RegistrationStepBuilder *(^)(NSString *))buttonTitle {
    __weak typeof(self) weakSelf = self;
    return ^RegistrationStepBuilder *(NSString *buttonTitle) {
        weakSelf.step.buttonTitle = lang(buttonTitle);
        return weakSelf;
    };
}

swiftPatternPrefixExceptions

Add here prefixes that tells that this is not localization key for sure, for example “Animation.named(“ for Animation.named(“animation_key”)

objCPatternPrefixExceptions
The same but for Obj C


keyNamePrefixExceptions

If you have some prefix for your keys, that tells that this is not a key for translation, add it. For example we use “ic_” as prefix for all icons.

keyNamePattern
Some specific rules for all your keys
Example: [_a-z0-9]*[_][a-z0-9]+ for Snake case

excludedTranslationKeys
Keys that the program mistakenly marks as unused

excludedKeys
Keys that the program mistakenly marks as not having a translation

folderExcludedNames
If file path has this string as part, it will be ignored
Example: “Pods”







# LocalizedStringsTool
