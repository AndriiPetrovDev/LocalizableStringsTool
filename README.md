# LocalizableStringsTool

## What is it

__LocalizableStringsTool__ is a tool that performs `Localizable.strings` analysis and helps you to clean up your translations

## Motivation

Unfortunately Xcode doesn't check translations on compile time,   
and sometimes you see `**user_greating_key**` instead of `Wellcome` in your app.  
__LocalizableStringsTool__ aims to ensure you that your localization is fine.

___If you use [SwiftGen](https://github.com/SwiftGen/SwiftGen "SwiftGen") or [R.swift](https://github.com/mac-cain13/R.swift "R.swift")  you probably don’t need this tool___

## Main Features

LocalizableStringsTool can help you find:
- Untranslated keys in your code
- Unused translations 
- Translation duplications
- Difference in keys set for every language pair

## How to use

* Prepare your custom settings file `LocalizableStringsTool.plist` otherwise the program will use default settings (see next section for details)  
Please check [__PlistExample__](https://github.com/AndrewPetrov/LocalizableStringsTool/tree/master/PlistExample "PlistExample")  folder for reference
* Just download [__LocalizableStringsTool executable file__](https://github.com/AndrewPetrov/LocalizableStringsTool/releases "file") from the latest release and execute it in your terminal  
-OR-
* Clone the project and compile it by yourself
* When the work is finished you will get the brief result in the terminal and a detailed one in `LocalizableStringsToolResults.txt` file

### Example of the program execution
![Example](https://github.com/AndrewPetrov/LocalizableStringsTool/blob/master/Screenshots/ExecutionExample.png)

## How to set up LocalizableStringsTool.plist

| Parameter Name        | Description           | Default value  |
| ---------------------- |:-------------------| -------------------:|
| projectRootFolderPath | Absolute path to your project root folder.<br>If it is absent the program will ask you for it |  |
| unusedTranslations   | Enable or disable searching for unused translations in your `Localizable.strings` files<br>      |   true |
| translationDuplication | Enable or disable searching for translation duplications in your `Localizable.strings` files<br>(Several keys with the same value (translation string)) |    true |
|untranslatedKeys| Enable or disable searching for keys without translation in your source code  |true|
|allUntranslatedStrings|Enable or disable searching for all strings, treating them as "keys" and adding<br>"untranslated" of them to a separate list at the end of `LocalizableStringsToolResults.txt` file.<br>Could be helpful for some hard cases.|false|
|differentKeysInTranslations|Enable or disable searching for key sets difference for language pairs.<br>For example `en` has 100 keys and `ru` has 110 keys.<br>Most likely you want to have the same keys amount for any language, and now you can see absent or added keys|true|
|shouldAnalyzeSwift|Enable or disable analyzing Swift files|true|
|shouldAnalyzeObjC|Enable or disable analyzing Objective-C files|true|
|customSwiftPatternPrefixes|If you use some custom wrappers for `NSLocalizedString("myKey", "comment")`.<br>For example it can be `lang(“myKey”)` and you should add here `lang(`|`NSLocalizedString(`|
|customSwiftPatternSuffixes|The same but for suffixes.<br>Add `.localized` if you use `“myKey”.localized` instead of `NSLocalizedString("myKey", "comment")`||
|customObjCPatternPrefixes|The same but for Obj C.<br>Also add here prefixes that can help the program to find keys in source code.<br>For example if you use keys as func parameters and made localisation inside it<br>```+ (void)showAlertInViewController:(UIViewController *)controller withTitle:(NSString *)title message:(NSString *)message```<br> and call it<br>```[AlertService showAlertInViewController:self withTitle:@"some_title" message:@"some_message"];```<br>you should add `withTitle:` and `message:` here|`NSLocalizedString(`|
|swiftPatternPrefixExceptions|Add here prefixes that tells that this is _not localization key for sure_.<br>For example `Animation.named(` for `Animation.named(“animation_key”)`||
|objCPatternPrefixExceptions|The same but for Obj C||
|keyNamePrefixExceptions|If you have some prefix for your keys, that tells that this is _not a key for translation_, add it.<br>For example somebody uses `ic_` as prefix for all icons||
|keyNamePattern|Some specific rules for all your keys.<br>Example: `[_a-z0-9]*[_][a-z0-9]+` for `snake_case`|`[.]+`|
|excludedUnusedKeys|Keys that the program mistakenly marks as unused.<br>Add them to prevent adding unwanted keys to the result||
|excludedUntranslatedKeys|Keys that the program mistakenly marks as not having a translation.<br>Add them to prevent adding unwanted keys to the result||
|excludedFoldersNameComponents|If file path has this string as part, it will be ignored.<br>you probably don't want to check translation of third party libraries|`Pods`|
