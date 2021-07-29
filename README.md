# LocalizedStringsTool

## What is it

__LocalizedStringsTool__ is a tool that performs `Localizable.strings` analysis and helps you to clean up your translations

Unfortunately Xcode doesn't check translations on compile time,   
and sometime you see `**user_greating_key**` instead of `Wellcome` in your app.  
__LocalizedStringsTool__ aims to ensure you that your localization is fine.

___If you use [SwiftGen](https://github.com/SwiftGen/SwiftGen "SwiftGen") or [R.swift](https://github.com/mac-cain13/R.swift "R.swift")  you probably don’t need this tool___

## Main Features

LocalizedStringsTool can help you find:
- Untranslated keys in your code
- Unused translations 
- Translation duplications
- Difference in keys set for every language pair

## How to use

* Prepare your custom settings file `LocalizedStringsTool.plist` otherwise the program will use default settings (see next section for details)
* Just download [__LocalizedStringsTool executable file__](https://github.com/AndrewPetrov/LocalizedStringsTool/blob/master/Precompiled/LocalizedStringsTool "file") and execute it in your terminal  
-OR-
* Clone the project and compile it by yourself

### Example of the program execution
![Example](https://github.com/AndrewPetrov/LocalizedStringsTool/blob/master/Images/Screenshot%202021-07-30%20at%2002.17.29.png)

## How to set up LocalizedStringsTool.plist

### projectRootFolderPath

Absolute path to your project root folder  
If it is absent the program will ask you for it

### unusedTranslations
Enable or disable searching for unused translations in your `Localizable.strings` files  
default: `true`

### translationDuplication
Enable or disable searching for translation duplications in your `Localizable.strings` files
(Several keys with the same value (translation string))  
default: `true`

### untranslatedKeys
Enable or disable searching for keys without translation in your source code  
default: `true`

### allUntranslatedStrings
Enable or disable searching for all strings, treating them as "keys" and adding
"untranslated keys" to separate list. Could be helpful for some hard cases.  
default: `false`

### differentKeysInTranslations
Enable or disable searching for key sets difference for language pairs  
For example “en” has 100 keys and “ru” has 110 keys.  
Most likely you want to have the same keys amount for any language and now you can see absent or added keys  
default: `true`

### shouldAnalyzeSwift
Enable or disable analyzing Swift files  
default: `true`

### shouldAnalyzeObjC
Enable or disable analyzing Objective C files  
default: `true`

### customSwiftPatternPrefixes
If you use some custom wrappers for `NSLocalizedString("key", "comment")`  
For example it can be `lang(“myKey”)` and you should add here `lang(`

### customSwiftPatternSuffixes
The same but for suffixes.   
Add `.localized` if you use `“myKey”.localized` instead of `NSLocalizedString("key", "comment")`

### customObjCPatternPrefixes
The same but for Obj C.   

Also add here prefixes that can help the program to find keys in source code
For example if you use keys as func parameters and made localisation inside it.
```objectivec
+ (void)showAlertInViewController:(UIViewController *)controller
                        withTitle:(NSString *)title
                          message:(NSString *)message
```

and call it  
```objectivec
[AlertService showAlertInViewController:self
                              withTitle:@"some_title"
                                message:@"some_message"];
```
you should add `withTitle:` and `message:` here

### swiftPatternPrefixExceptions

Add here prefixes that tells that this is _not localization key for sure_.  
For example `Animation.named(` for `Animation.named(“animation_key”)`

### objCPatternPrefixExceptions
The same but for Obj C

### keyNamePrefixExceptions
If you have some prefix for your keys, that tells that this is _not a key for translation_, add it.  
For example somebody uses `ic_` as prefix for all icons.

### keyNamePattern
Some specific rules for all your keys  
Example: `[_a-z0-9]*[_][a-z0-9]+` for Snake case

### excludedUnusedKeys
Keys that the program mistakenly marks as unused  
Add them to prevent adding unwanted keys to the result

### excludedUntranslatedKeys
Keys that the program mistakenly marks as not having a translation  
Add them to prevent adding unwanted keys to the result

### excludedFoldersNameComponents
If file path has this string as part, it will be ignored  
Example: `Pods`


